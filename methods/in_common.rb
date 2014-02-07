
# Code common to all services

# Tune OS X NFS

def tune_osx_nfs()
  nfs_file   = "/etc/nfs.conf"
  nfs_params = ["nfs.server.nfsd_threads = 64","nfs.server.reqcache_size = 1024","nfs.server.tcp = 1","nfs.server.udp = 0","nfs.server.fsevents = 0"]
  nfs_params.each do |nfs_tune|
    nfs_tune = "nfs.client.nfsiod_thread_max = 64"
    message  = "Checking:\tNFS tuning"
    command  = "cat #{nfs_file} |grep '#{nfs_tune}'"
    output   = execute_command(message,command)
    if !output.match(/#{nfs_tune}/)
      backup_file(nfs_file)
      message = "Tuning:\tNFS"
      command = "echo '#{nfs_tune}' >> #{nfs_file}"
      execute_command(message,command)
    end
  end
  return
end

# Add NFS export

def add_nfs_export(export_name,export_dir,publisher_host)
  network_address  = publisher_host.split(/\./)[0..2].join(".")+".0"
  if $os_name.match(/SunOS/)
    if $os_rel.match(/11/)
      message  = "Enabling:\tNFS share on "+export_dir
      command  = "zfs set sharenfs=on #{$default_zpool}#{export_dir}"
      output   = execute_command(message,command)
      message  = "Setting:\tNFS access rights on "+export_dir
      command  = "zfs set share=name=#{export_name},path=#{export_dir},prot=nfs,anon=0,sec=sys,ro=@#{network_address}/24 #{$default_zpool}#{export_dir}"
      output   = execute_command(message,command)
    else
      dfs_file = "/etc/dfs/dfstab"
      message  = "Checking:\tCurrent NFS exports for "+export_dir
      command  = "cat #{dfs_file} |grep '#{export_dir}' |grep -v '^#'"
      output   = execute_command(message,command)
      if !output.match(/#{export_dir}/)
        backup_file(dfs_file)
        export  = "share -F nfs -o ro=@#{network_address},anon=0 #{export_dir}"
        message = "Adding:\tNFS export for "+export_dir
        command = "echo '#{export}' >> #{dfs_file}"
        execute_command(message,command)
        message = "Refreshing:\tNFS exports"
        command = "shareall -F nfs"
        execute_command(message,command)
      end
    end
  else
    dfs_file = "/etc/exports"
    message  = "Checking:\tCurrent NFS exports for "+export_dir
    command  = "cat #{dfs_file} |grep '#{export_dir}' |grep -v '^#'"
    output   = execute_command(message,command)
    if !output.match(/#{export_dir}/)
      if $os_name.match(/Darwin/)
        export = "#{export_dir} -alldirs -maproot=root -network #{network_address} -mask #{$default_netmask}"
      else
        export = "#{export_dir} #{network_address}/24(ro,no_root_squash,async,no_subtree_check)"
      end
      message = "Adding:\tNFS export for "+export_dir
      command = "echo '#{export}' >> #{dfs_file}"
      execute_command(message,command)
      message = "Refreshing:\tNFS exports"
      if $os_name.match(/Darwin/)
        command = "nfsd stop ; nfsd start"
      else
        command = "/sbin/exportfs -a"
      end
      execute_command(message,command)
    end
  end
  return
end

# Remove NFS export

def remove_nfs_export(export_dir)
  if $os_name.match(/SunOS/)
    message = "Disabling:\tNFS share on "+export_dir
    command = "zfs set sharenfs=off #{$default_zpool}#{export_dir}"
    execute_command(message,command)
  else
    dfs_file = "/etc/exports"
    message  = "Checking:\tCurrent NFS exports for "+export_dir
    command  = "cat #{dfs_file} |grep '#{export_dir}' |grep -v '^#'"
    output   = execute_command(message,command)
    if output.match(/#{export_dir}/)
      backup_file(dfs_file)
      tmp_file = "/tmp/dfs_file"
      message  = "Removing:\tExport "+export_dir
      command  = "cat #{dfs_file} |grep -v '#{export_dir}' > #{tmp_file} ; cat #{tmp_file} > #{dfs_file} ; rm #{tmp_file}"
      execute_command(message,command)
      if $os_name.match(/Darwin/)
        message  = "Restarting:\tNFS daemons"
        command  = "nfsd stop ; nfsd start"
        execute_command(message,command)
      else
        message  = "Restarting:\tNFS daemons"
        command  = "service nfsd restart"
        execute_command(message,command)
      end
    end
  end
  return
end

# Check we are running on the right architecture

def check_same_arch(client_arch)
  if !$os_arch.match(/#{client_arch}/)
    puts "Warning:\tSystem and Zone Architecture do not match"
    exit
  end
  return
end

# Delete file

def delete_file(file_name)
  if File.exist?(file_name)
    message = "Removing:\tFile "+file_name
    command = "rm #{file_name}"
    execute_command(message,command)
  end
end

# Get root password crypt

def get_root_password_crypt()
  password = $q_struct["root_password"].value
  result   = get_password_crypt(password)
  return result
end

# Get account password crypt

def get_admin_password_crypt()
  password = $q_struct["admin_password"].value
  result   = get_password_crypt(password)
  return result
end

# Check SSH keys

def check_ssh_keys()
  ssh_key = $home_dir+"/.ssh/id_rsa.pub"
  if !File.exist?(ssh_key)
    if $verbose_mode == 1
      puts "Generating:\tPublic SSH key file "+ssh_key
    end
    system("ssh-keygen -t rsa")
  end
  return
end

# Check IPS tools installed on OS other than Solaris

def check_ips()
  if $os_name.match(/Darwin/)
    check_osx_ips()
  end
  return
end

# Get Mac disk name

def get_osx_disk_name()
  message = "Getting:\tRoot disk device ID"
  command = "df |grep '/$' |awk '{print \\$1}'"
  output  = execute_command(message,command)
  disk_id = output.chomp
  message = "Getting:\tVolume name for "+disk_id
  command = "diskutil info #{disk_id} | grep 'Volume Name' |cut -f2 -d':'"
  output  = execute_command(message,command)
  volume  = output.chomp.gsub(/^\s+/,"")
  return volume
end

# Check OSX Puppet install

def check_osx_puppet_install()
  pkg_list = {}
  use_rvm  = 0
  pkg_list["facter"] = $facter_version
  pkg_list["hiera"]  = $hiera_version
  pkg_list["puppet"] = $puppet_version
  base_url  = "http://downloads.puppetlabs.com/mac/"
  local_dir = $work_dir+"/dmg"
  check_dir_exists(local_dir)
  pkg_list.each do |key, value|
    test_file = "/usr/bin/"+key
    if !File.exist?(test_file)
      file_name   = key+"-"+value
      dmg_name    = file_name+".dmg"
      local_pkg   = key+"-"+value+".pkg"
      remote_file = base_url+"/"+dmg_name
      local_file  = local_dir+"/"+dmg_name
      if !File.exist?(local_file)
        wget_file(remote_file,local_file)
      end
      message = "Mounting:\tDisk image "+local_file
      command = "hdiutil mount #{local_file}"
      execute_command(message,command)
      local_pkg = "/Volumes/"+file_name+"/"+local_pkg
      volume    = get_osx_disk_name()
      volume    = "/Volumes/"+volume
      message   = "Installing:\tPackage "+local_pkg
      command   = "installer -package #{local_pkg} -target '#{volume}'"
      execute_command(message,command)
      if key.match(/puppet/)
        message = "Checking:\tRuby version"
        command = "which ruby"
        output  = execute_command(message,command)
        if output.match(/rvm/)
          use_rvm  = 1
          message  = "Storing:\tRVM Ruby version"
          command  = "rvm current"
          output   = execute_command(message,command)
          rvm_ruby = output.chomp
          message  = "Setting:\tRVM to use system ruby"
          command  = "rvm use system"
          execute_command(message,command)
        end
        message = "Creating:\tPuppet group"
        command = "puppet resource group puppet ensure=present"
        execute_command(message,command)
        message = "Creating:\tPuppet user"
        command = "puppet resource user puppet ensure=present gid=puppet shell='/sbin/nologin'"
        execute_command(message,command)
        etc_dir = "/etc/puppet"
        check_dir_exists(etc_dir)
        message = "Creating:\tPuppet directory"
        command = "mkdir -p /var/lib/puppet ; mkdir -p /etc/puppet/manifests ; mkdir -p /etc/puppet/ssl"
        execute_command(message,command)
        message = "Fixing:\tPuppet permissions"
        command = "chown -R puppet:puppet  /var/lib/puppet ; chown -R puppet:puppet  /etc/puppet"
        execute_command(message,command)
        if use_rvm == 1
          message = "Reverting:\tRVM to use "+rvm_ruby
          command = "rvm use rvm_ruby"
          execute_command(message,command)
        end
      end
      local_vol = "/Volumes/"+key+"-"+value
      message   = "Unmounting:\t"+local_vol
      command   = "umount "+local_vol
      execute_command(message,command)
    end
  end

  return
end

# Create OS X Puppet agent plist file

def create_osx_puppet_agent_plist()
  xml_output = []
  plist_file = "/Library/LaunchDaemons/com.puppetlabs.puppet.plist"
  tmp_file   = "/tmp/puppet.plist"
  plist_name = "com.puppetlabs.puppet"
  puppet_bin = "/usr/bin/puppet"
  message    = "Checking:\tPuppet configruation"
  command    = "cat #{plist_file} | grep 'agent'"
  output     = execute_command(message,command)
  if !output.match(/#{$default_net}/)
    xml = Builder::XmlMarkup.new(:target => xml_output, :indent => 2)
    xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    xml.declare! :DOCTYPE, :plist, :PUBLIC, :'"-//Apple Computer//DTD PLIST 1.0//EN"', :'"http://www.apple.com/DTDs/PropertyList-1.0.dtd"'
    xml.plist(:version => "1.0") {
      xml.dict {
        xml.key("EnvironmentVariables")
        xml.dict {
          xml.key("PATH")
          xml.string("/sbin:/usr/sbin:/bin:/usr/bin")
          xml.key("RUBYLIB")
          xml.string("/usr/lib/ruby/site_ruby/1.8/")
        }
        xml.key("label")
        xml.string(plist_name)
        xml.key("OnDemand") ; xml.false
        xml.key("ProgramArguments")
        xml.array {
          xml.string(puppet_bin)
          xml.string("agent")
          xml.string("--verbose")
          xml.string("--no-daemonize")
          xml.string("--log-dest")
          xml.string("console")
        }
      }
      xml.key("RunAtLoad") ; xml.true
      xml.key("ServiceIPC") ; xml.false
      xml.key("StandardErrorPath")
      xml.string("/var/log/puppet/puppet.err")
      xml.key("StandardOutPath")
      xml.string("/var/log/puppet/puppet.out")
    }
    file=File.open(tmp_file,"w")
    xml_output.each do |item|
      file.write(item)
    end
    file.close
    message = "Creating:\tService file "+plist_file
    command = "cp #{tmp_file} #{plist_file} ; rm #{tmp_file} ; chown root:wheel #{plist_file} ; chmod 644 #{plist_file}"
    execute_command(message,command)
  end
  return
end

# Create OS X Puppet master plist file

def create_osx_puppet_master_plist()
  xml_output = []
  plist_file = "/Library/LaunchDaemons/com.puppetlabs.puppetmaster.plist"
  tmp_file   = "/tmp/puppetmaster.plist"
  plist_name = "com.puppetlabs.puppetmaster"
  puppet_bin = "/usr/bin/puppet"
  message    = "Checking:\tPuppet configruation"
  command    = "cat #{plist_file} | grep 'master'"
  output     = execute_command(message,command)
  if !output.match(/#{$default_net}/)
    xml = Builder::XmlMarkup.new(:target => xml_output, :indent => 2)
    xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    xml.declare! :DOCTYPE, :plist, :PUBLIC, :'"-//Apple Computer//DTD PLIST 1.0//EN"', :'"http://www.apple.com/DTDs/PropertyList-1.0.dtd"'
    xml.plist(:version => "1.0") {
      xml.dict {
        xml.key("EnvironmentVariables")
        xml.dict {
          xml.key("PATH")
          xml.string("/sbin:/usr/sbin:/bin:/usr/bin")
          xml.key("RUBYLIB")
          xml.string("/usr/lib/ruby/site_ruby/1.8/")
        }
        xml.key("label")
        xml.string(plist_name)
        xml.key("ProgramArguments")
        xml.array {
          xml.string(puppet_bin)
          xml.string("master")
          xml.string("--verbose")
          xml.string("--no-daemonize")
        }
      }
      xml.key("RunAtLoad") ; xml.true
      xml.key("ServiceIPC") ; xml.false
      xml.key("StandardErrorPath")
      xml.string("/var/log/puppet/puppetmaster.err")
      xml.key("StandardOutPath")
      xml.string("/var/log/puppet/puppetmaster.out")
    }
    file=File.open(tmp_file,"w")
    xml_output.each do |item|
      file.write(item)
    end
    file.close
    message = "Creating:\tService file "+plist_file
    command = "cp #{tmp_file} #{plist_file} ; rm #{tmp_file} ; chown root:wheel #{plist_file} ; chmod 644 #{plist_file}"
    execute_command(message,command)
  end
  return
end

# Check OX X Puppet plist

def check_osx_puppet_plist()
  plist_file = "/Library/LaunchDaemons/com.puppetlabs.puppet.plist"
  plist_name = "com.puppetlabs.puppet"
  if !File.exist?(plist_file)
    create_osx_puppet_plist()
    message = "Loading:\tPuppet Agent plist file "+plist_file
    command = "launchctl load -w #{plist_file}"
    execute_command(message,command)
    message = "Loading:\tStarting Puppet Agent "+plist_name
    command = "launchctl start #{plist_name}"
    execute_command(message,command)
  end
  plist_file = "/Library/LaunchDaemons/com.puppetlabs.puppetmaster.plist"
  plist_name = "com.puppetlabs.puppetmaster"
  if !File.exist?(plist_file)
    create_osx_puppet_master_plist()
    message = "Loading:\tPuppet Master plist file "+plist_file
    command = "launchctl load -w #{plist_file}"
    execute_command(message,command)
    message = "Loading:\tStarting Puppet Master "+plist_name
    command = "launchctl start #{plist_name}"
    execute_command(message,command)
  end
  return
end

# Create OS X Puppet config

def create_osx_puppet_config()
  tmp_file    = "/tmp/puppet_config"
  puppet_file = "/etc/puppet/puppet.conf"
  if !File.exist?(puppet_file)
    config = []
    config.push("[main]")
    config.push("pluginsync = true")
    config.push("server = #{$default_host}")
    config.push("")
    config.push("[master]")
    config.push("vardir = /var/lib/puppet")
    config.push("libdir = $vardir/lib")
    config.push("ssldir = /etc/puppet/ssl")
    config.push("certname = #{$default_host}")
    config.push("")
    config.push("[agent]")
    config.push("vardir = /var/lib/puppet")
    config.push("libdir = $vardir/lib")
    config.push("ssldir = /etc/puppet/ssl")
    config.push("certname = #{$default_host}")
    config.push("")
    file = File.open(tmp_file,"w")
    config.each do |line|
      output = line+"\n"
      file.write(output)
    end
    file.close
    message = "Creating:\tPuppet configuration file "+puppet_file
    command = "cp #{tmp_file} #{puppet_file} ; rm #{tmp_file}"
    execute_command(message,command)
    if $verbose_mode == 1
      puts
      puts "Information: Contents of "+puppet_file
      puts
      system("cat #{puppet_file}")
      puts
    end
  end
  return
end

# Check OS X Puppet

def check_osx_puppet()
  check_osx_puppet_install()
  check_osx_puppet_plist()
  create_osx_puppet_config()
  return
end

# Check OS X IPS

def check_osx_ips()
  python_bin = "/usr/bin/python"
  pip_bin    = "/usr/bin/pip"
  setup_url  = "https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py"
  if !File.symlink?(pip_bin)
    message = "Installing:\tPip"
    command = "/usr/bin/easy_install --prefix=/usr pip"
    execute_command(message,command)
    message = "Updating:\tSetuptools"
    command = "wget #{setup_url} -O |sudo #{python_bin}"
    execute_command(message,command)
    ["simplejson","coverage","pyOpenSSL","mercurial"].each do |module_name|
      message = "Installing:\tPython module "+module_name
      command = "#{pip_bin} install #{module_name}"
      execute_command(message,command)
    end
  end
  python_ver = %x[#{python_bin} --version |awk '{print $2}']
  python_ver = python_ver.chomp.split(/\./)[0..1].join(".")
  module_dir = "/usr/local/lin/python"+python_ver+"/site-packages"
  pkg_dest_dir = module_dir+"/pkg"
  check_dir_exists(pkg_dest_dir)
  hg_bin = "/usr/local/bin/hg"
  if !File.exist?(hg_bin)
    message = "Installing:\tMercurial"
    command = "brew install mercurial"
    execute_command(message,command)
  end
  pkgrepo_bin = "/usr/local/bin/pkgrepo"
  if !File.exist?(pkgrepo_bin)
    ips_url = "https://hg.java.net/hg/ips~pkg-gate"
    message = "Downloading:\tIPS source code"
    command = "cd #{$work_dir} ; hg clone #{ips_url} ips"
    execute_command(message,command)
  end
  return
end

# Check Apache enabled

def check_apache_config()
  if $os_name.match(/Darwin/)
    service = "apache"
    check_osx_service_is_enabled(service)
  end
  return
end

# Process ISO file to get details

def get_linux_version_info(iso_file_name)
  iso_info     = File.basename(iso_file_name)
  iso_info     = iso_info.split(/-/)
  linux_distro = iso_info[0]
  linux_distro = linux_distro.downcase
  if linux_distro.match(/oraclelinux/)
    linux_distro = "oel"
  end
  if linux_distro.match(/centos|ubuntu|sles|sl|oel/)
    if linux_distro.match(/sles/)
      iso_version = iso_info[1]+"."+iso_info[2]
      iso_version = iso_version.gsub(/SP/,"")
    else
      if linux_distro.match(/sl$/)
        iso_version = iso_info[1].split(//).join(".")
      else
        if linux_distro.match(/oel/)
          iso_version = iso_info[1]+"."+iso_info[2]
          iso_version = iso_version.gsub(/[A-z]/,"")
        else
          iso_version = iso_info[1]
        end
      end
    end
    if linux_distro.match(/centos|sl$/)
      iso_arch = iso_info[2]
    else
      if linux_distro.match(/sles|oel/)
        iso_arch = iso_info[4]
      else
        iso_arch = iso_info[3]
        iso_arch = iso_arch.split(/\./)[0]
        if iso_arch.match(/amd64/)
          iso_arch = "x86_64"
        else
          iso_arch = "i386"
        end
      end
    end
  else
    iso_version = iso_info[2]
    iso_arch    = iso_info[3]
  end
  return linux_distro,iso_version,iso_arch
end


# List ISOs

def list_linux_isos(search_string)
  iso_list      = check_iso_base_dir(search_string)
  iso_list.each do |iso_file_name|
    iso_file_name = iso_file_name.chomp
    (linux_distro,iso_version,iso_arch) = get_linux_version_info(iso_file_name)
    puts "ISO file:\t"+iso_file_name
    puts "Distribution:\t"+linux_distro
    puts "Version:\t"+iso_version
    puts "Architecture:\t"+iso_arch
    iso_version      = iso_version.gsub(/\./,"_")
    service_name     = linux_distro+"_"+iso_version+"_"+iso_arch
    repo_version_dir = $repo_base_dir+"/"+service_name
    if File.directory?(repo_version_dir)
      puts "Service Name:\t"+service_name+" (exists)"
    else
      puts "Service Name:\t"+service_name
    end
    puts
  end
  return
end

# Check DHCPd config

def check_dhcpd_config(publisher_host)
  network_address   = $default_host.split(/\./)[0..2].join(".")+".0"
  broadcast_address = $default_host.split(/\./)[0..2].join(".")+".255"
  gateway_address   = $default_host.split(/\./)[0..2].join(".")+".254"
  output = ""
  if File.exist?($dhcpd_file)
    message = "Checking:\tDHCPd config for subnet entry"
    command = "cat #{$dhcpd_file} | grep 'subnet #{network_address}'"
    output  = execute_command(message, command)
  end
  if !output.match(/subnet/)
    tmp_file    = "/tmp/dhcpd"
    backup_file = $dhcpd_file+".premodest"
    file = File.open(tmp_file,"w")
    file.write("\n")
    file.write("default-lease-time 900;\n")
    file.write("max-lease-time 86400;\n")
    file.write("\n")
    file.write("authoritative;\n")
    file.write("\n")
    file.write("option arch code 93 = unsigned integer 16;\n")
    file.write("option grubmenu code 150 = text;\n")
    file.write("\n")
    file.write("log-facility local7;\n")
    file.write("\n")
    file.write("class \"PXEBoot\" {\n")
    file.write("  match if (substring(option vendor-class-identifier, 0, 9) = \"PXEClient\");\n")
    file.write("}\n")
    file.write("\n")
    file.write("class \"SPARC\" {\n")
    file.write("  match if not (substring(option vendor-class-identifier, 0, 9) = \"PXEClient\");\n")
    file.write("  filename \"http://#{publisher_host}:5555/cgi-bin/wanboot-cgi\";\n")
    file.write("}\n")
    file.write("\n")
    file.write("allow booting;\n")
    file.write("allow bootp;\n")
    file.write("\n")
    file.write("subnet #{network_address} netmask #{$default_netmask} {\n")
    file.write("  option broadcast-address #{broadcast_address};\n")
    file.write("  option routers #{gateway_address};\n")
    file.write("  next-server #{$default_host};\n")
    file.write("}\n")
    file.write("\n")
    file.close
    message = "Archiving:\tDHCPd configuration file "+$dhcpd_file+" to "+backup_file
    command = "cp #{$dhcpd_file} #{backup_file}"
    execute_command(message,command)
    message = "Creating:\tDHCPd configuration file "+$dhcpd_file
    command = "cp #{tmp_file} #{$dhcpd_file}"
    execute_command(message,command)
    restart_dhcpd()
  end
  return
end

# Check TFTPd enabled on CentOS / RedHat

def check_yum_tftpd()
  message = "Checking:\tTFTPd is installed"
  command = "rpm -q tftp-server"
  output  = execute_command(message,command)
  if !output.match(/tftp/)
    message = "installing:\tTFTPd"
    command = "yum -y install tftp-server"
    execute_command(message,command)
    check_dir_exists($tftp_dir)
    message = "Enabling:\tTFTPd"
    command = "chkconfig tftp on"
    execute_command(message,command)
  end
  return
end

# Check DHCPd enabled on CentOS / RedHat

def check_yum_dhcpd()
  message = "Checking:\tDHCPd is installed"
  command = "rpm -q dhcp"
  output  = execute_command(message,command)
  if !output.match(/dhcp/)
    message = "installing:\tDHCPd"
    command = "yum -y install dhcp"
    execute_command(message,command)
    message = "Enabling:\tDHCPd"
    command = "chkconfig dhcpd on"
    execute_command(message,command)
  end
  return
end

# Check TFTPd enabled on CentOS / RedHat

def check_apt_tftpd()
  tftpd_file = "/etc/xinetd.d/tftp"
  tmp_file   = "/tmp/tftp"
  message    = "Checking:\tTFTPd is installed"
  command    = "dpkg -l tftpd |grep '^ii'"
  output     = execute_command(message,command)
  if !output.match(/tftp/)
    message = "installing:\tTFTPd"
    command = "apt-get -y install tftpd"
    execute_command(message,command)
    check_dir_exists($tftp_dir)
    if !File.exist?(tftpd_file)
      file=File.open(tmp_file,"w")
      file.write("service tftp\n")
      file.write("{\n")
      file.write("protocol        = udp\n")
      file.write("port            = 69\n")
      file.write("socket_type     = dgram\n")
      file.write("wait            = yes\n")
      file.write("user            = nobody\n")
      file.write("server          = /usr/sbin/in.tftpd\n")
      file.write("server_args     = /tftpboot\n")
      file.write("disable         = no\n")
      file.write("}\n")
    end
    message = "Creating:\tTFTPd configuration file "+tftpd_file
    command = "cp #{tmp_file} #{tftpd_file} ; rm #{tmp_file}"
    execute_command(message,command)
    message = "Enabling:\tTFTPd"
    command = "/etc/init.d/xinetd restart"
    execute_command(message,command)
  end
  return
end

# Check DHCPd enabled on CentOS / RedHat

def check_apt_dhcpd()
  message = "Checking:\tDHCPd is installed"
  command = "dpkg -l isc-dhcp-server |grep '^ii'"
  output  = execute_command(message,command)
  if !output.match(/dhcp/)
    message = "installing:\tDHCPd"
    command = "yum -y install isc-dhcp-server"
    execute_command(message,command)
    message = "Enabling:\tDHCPd"
    command = "chkconfig dhcpd on"
    execute_command(message,command)
  end
  return
end

def restart_tftpd()
  service = "tftp"
  service = get_service_name(service)
  refresh_service(service)
end

# Check tftpd

def check_tftpd()
  if $os_name.match(/Darwin/)
    check_osx_tftpd()
  end
  return
end

# Check OSX service is enabled

def check_osx_service_is_enabled(service)
  service     = get_service_name(service)
  plist_file  = "/Library/LaunchDaemons/"+service+".plist"
  if !File.exist?(plist_file)
    plist_file = "/System"+plist_file
  end
  if !File.exist?(plist_file)
    puts "Warning:\tLaunch Agent not found for "+service
    exit
  end
  tmp_file  = "/tmp/tmp.plist"
  message   = "Checking:\tService "+service+" is enabled"
  if service.match(/dhcp/)
    command   = "cat #{plist_file} | grep Disabled |grep true"
  else
    command   = "cat #{plist_file} | grep -C1 Disabled |grep true"
  end
  output    = execute_command(message,command)
  if !output.match(/true/)
    if $verbose_mode == 1
      puts "Information:\t"+service+" enabled"
    end
  else
    backup_file(plist_file)
    copy      = []
    check     = 0
    file_info = IO.readlines(plist_file)
    file_info.each do |line|
      if line.match(/Disabled/)
        check = 1
      end
      if line.match(/Label/)
        check = 0
      end
      if check == 1 and line.match(/true/)
        copy.push(line.gsub(/true/,"false"))
      else
        copy.push(line)
      end
    end
    File.open(tmp_file,"w") {|file| file.puts copy}
    message = "Enabling:\t"+service
    command = "cp #{tmp_file} #{plist_file} ; rm #{tmp_file}"
    execute_command(message,command)
    message = "Loading:\t"+service+" profile"
    command = "launchctl load -w #{plist_file}"
    execute_command(message,command)
  end
  return
end

# Check TFTPd enabled on OS X

def check_osx_tftpd()
  service = "tftp"
  check_osx_service_is_enabled(service)
  return
end

# Check OSX brew package

def check_brew_pkg(pkg_name)
  message = "Checking:\tBrew package "+pkg_name
  command = "brew info #{pkg_name}"
  output  = execute_command(message,command)
  return output
end

# Check OSC DHCP installation on OS X

def check_osx_dhcpd_installed()
  brew_file   = "/usr/local/Library/Formula/isc-dhcp.rb"
  backup_file = brew_file+".orig"
  dhcpd_bin   = "/usr/local/sbin/dhcpd"
  if !File.symlink?(dhcpd_bin)
    message = "Installing:\tBind (required for ISC DHCPd server)"
    command = "brew install bind"
    execute_command(message,command)
    message = "Updating:\tBrew sources list"
    command = "brew update"
    execute_command(message,command)
    message = "Checking:\rOS X Version"
    command = "sw_vers |grep ProductVersion |awk '{print $2}'"
    output  = execute_command(message,command)
    if output.match(/10\.9/)
      if File.exist?(brew_file)
        message = "Checking:\tVersion of ISC DHCPd"
        command = "cat #{brew_file} | grep url"
        output  = execute_command(message,command)
        if output.match(/4\.2\.5\-P1/)
          message = "Archiving:\tBrew file "+brew_file+" to "+backup_file
          command = "cp #{brew_file} #{backup_file}"
          execute_command(message,command)
          message = "Fixing:\tBrew configuration file "+brew_file
          command = "cat #{backup_file} | grep -v sha1 | sed 's/4\.2\.5\-P1/4\.3\.0rc1/g' > #{brew_file}"
          execute_command(message,command)
        end
        message = "Installing:\tDHCPd server"
        command = "brew install isc-dhcp"
        execute_command(message,command)
      end
        message = "Creating:\tLaunchd service for ISC DHCPd"
        command = "cp -fv /usr/local/opt/isc-dhcp/*.plist /Library/LaunchDaemons"
        execute_command(message,command)
    end
    if !File.exist?($dhcpd_file)
      message = "Creating:\tDHCPd configuration file "+$dhcpd_file
      command = "touch #{$dhcpd_file}"
      execute_command(message,command)
    end
  end
  return
end

# Build DHCP plist file

def create_osx_dhcpd_plist()
  xml_output = []
  tmp_file   = "/tmp/plist.xml"
  plist_name = "homebrew.mxcl.isc-dhcp"
  plist_file = "/Library/LaunchDaemons/homebrew.mxcl.isc-dhcp.plist"
  dhcpd_bin  = "/usr/local/sbin/dhcpd"
  message    = "Checking:\tDHCPd configruation"
  command    = "cat #{plist_file} | grep '#{$default_net}'"
  output     = execute_command(message,command)
  if !output.match(/#{$default_net}/)
    xml = Builder::XmlMarkup.new(:target => xml_output, :indent => 2)
    xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
    xml.declare! :DOCTYPE, :plist, :PUBLIC, :'"-//Apple Computer//DTD PLIST 1.0//EN"', :'"http://www.apple.com/DTDs/PropertyList-1.0.dtd"'
    xml.plist(:version => "1.0") {
      xml.dict {
        xml.key("label")
        xml.string(plist_name)
        xml.key("ProgramArguments")
        xml.array {
          xml.string(dhcpd_bin)
          xml.string($default_net)
          xml.string("-4")
          xml.string("-f")
        }
      }
      xml.key("Disabled") ; xml.false
      xml.key("KeepAlive") ; xml.true
      xml.key("RunAtLoad") ; xml.true
      xml.key("LowPriorityID") ; xml.true
    }
    file=File.open(tmp_file,"w")
    xml_output.each do |item|
      file.write(item)
    end
    file.close
    message = "Creating:\tService file "+plist_file
    command = "cp #{tmp_file} #{plist_file} ; rm #{tmp_file}"
    execute_command(message,command)
  end
  return
end

# Check ISC DHCP installed on OS X

def check_osx_dhcpd()
  check_osx_dhcpd_installed()
  create_osx_dhcpd_plist()
  service = "dhcp"
  check_osx_service_is_enabled(service)
  return
end

# Get client IP

def get_client_ip(client_name)
  hosts_file = "/etc/hosts"
  message    = "Getting:\tClient IP for "+client_name
  command    = "cat #{hosts_file} |grep '#{client_name}$' |awk '{print $1}'"
  output     = execute_command(message,command)
  client_ip  = output.chomp
  return client_ip
end

# Add hosts entry

def add_hosts_entry(client_name,client_ip)
  hosts_file = "/etc/hosts"
  message    = "Checking:\tHosts file for "+client_name
  command    = "cat #{hosts_file} |grep -v '^#' |grep '#{client_name}' |grep '#{client_ip}'"
  output     = execute_command(message,command)
  if !output.match(/#{client_name}/)
    backup_file(hosts_file)
    message = "Adding:\t\tHost "+client_name+" to "+hosts_file
    command = "echo '#{client_ip} #{client_name}' >> #{hosts_file}"
    output  = execute_command(message,command)
  end
  return
end

# Remove hosts entry

def remove_hosts_entry(client_name,client_ip)
  tmp_file   = "/tmp/hosts"
  hosts_file = "/etc/hosts"
  message    = "Checking:\tHosts file for "+client_name
  command    = "cat #{hosts_file} |grep -v '^#' |grep '#{client_name}' |grep '#{client_ip}'"
  output     = execute_command(message,command)
  copy       = []
  if output.match(/#{client_name}/)
    file_info=IO.readlines(hosts_file)
    file_info.each do |line|
      if !line.match(/^#{client_ip}/)
        if !line.match(/#{client_name}/)
          copy.push(line)
        end
      end
    end
    File.open(tmp_file,"w") {|file| file.puts copy}
    message = "Updating:\tHosts file "+hosts_file
    command = "cp #{tmp_file} #{hosts_file} ; rm #{tmp_file}"
    execute_command(message,command)
  end
  return
end

# Add host to DHCP config

def add_dhcp_client(client_name,client_mac,client_ip,client_arch,service_name)
  tmp_file = "/tmp/dhcp_"+client_name
  if !client_arch.match(/sparc/)
    tftp_pxe_file = client_mac.gsub(/:/,"")
    tftp_pxe_file = tftp_pxe_file.upcase
    if service_name.match(/sol/)
      suffix = ".bios"
    else
      suffix = ".pxelinux"
    end
    tftp_pxe_file = "01"+tftp_pxe_file+suffix
  else
    tftp_pxe_file = "http://#{$default_host}:5555/cgi-bin/wanboot-cgi"
  end
  message = "Checking:\fIf DHCPd configuration contains "+client_name
  command = "cat #{$dhcpd_file} | grep '#{client_name}'"
  output  = execute_command(message,command)
  if !output.match(/#{client_name}/)
    backup_file($dhcpd_file)
    file = File.open(tmp_file,"w")
    file_info=IO.readlines($dhcpd_file)
    file_info.each do |line|
      file.write(line)
    end
    file.write("\n")
    file.write("host #{client_name} {\n")
    file.write("  fixed-address #{client_ip};\n")
    file.write("  hardware ethernet #{client_mac};\n")
    file.write("  filename \"#{tftp_pxe_file}\";\n")
    file.write("}\n")
    file.close
    message = "Updating:\tDHCPd file "+$dhcpd_file
    command = "cp #{tmp_file} #{$dhcpd_file} ; rm #{tmp_file}"
    execute_command(message,command)
    restart_dhcpd()
  end
  check_dhcpd()
  return
end

# Remove host from DHCP config

def remove_dhcp_client(client_name)
  found     = 0
  copy      = []
  file_info = IO.readlines($dhcpd_file)
  file_info.each do |line|
    if line.match(/^host #{client_name}/)
      found=1
    end
    if found == 0
      copy.push(line)
    end
    if found == 1 and line.match(/\}/)
      found=0
    end
  end
  File.open(file_name,"w") {|file| file.puts copy}
  return
end

# Backup file

def backup_file(file_name)
  date_string = get_date_string()
  backup_file = File.basename(file_name)+"."+date_string
  backup_file = $backup_dir+backup_file
  message     = "Archiving:\tFile "+file_name+" to "+backup_file
  command     = "cp #{file_name} #{backup_file}"
  execute_command(message,command)
  return
end

# Wget a file

def wget_file(file_url,file_name)
  file_dir = File.dirname(file_name)
  check_dir_exists(file_dir)
  message  = "Fetching:\tURL "+file_url+" to "+file_name
  command  = "wget #{file_url} -O #{file_name}"
  execute_command(message,command)
  return
end
# Find client MAC

def get_client_mac(client_name)
  ethers_file = "/etc/ethers"
  output      = ""
  found       = 0
  if File.exist?(ethers_file)
    message    = "Checking:\tFile "+ethers_file+" for "+client_name+" MAC address"
    command    = "cat #{ethers_file} |grep '#{client_name} '|awk '{print $2}'"
    client_mac = execute_command(message,command)
    client_mac = client_mac.chomp
  end
  if !output.match(/[0-9]/)
    file=IO.readlines($dhcpd_file)
    file.each do |line|
      line=line.chomp
      if line.match(/#{client_name}/)
        found=1
      end
      if found == 1
        if line.match(/ethernet/)
          client_mac = line.split(/ ethernet /)[1]
          client_mac = client_mac.gsub(/\;/,"")
          return client_mac
        end
      end
    end
  end
  return client_mac
end

# Check if a directory exists
# If not create it

def check_dir_exists(dir_name)
  output  = ""
  if !File.directory?(dir_name) and !File.symlink?(dir_name)
    message = "Creating:\t"+dir_name
    command = "mkdir -p '#{dir_name}'"
    output  = execute_command(message,command)
  end
  return output
end

# Check a filesystem / directory exists

def check_fs_exists(dir_name)
  output = ""
  if $os_name.match(/SunOS/)
    output = check_zfs_fs_exists(dir_name)
  else
    check_dir_exists(dir_name)
  end
  return output
end

# Check if a ZFS filesystem exists
# If not create it

def check_zfs_fs_exists(dir_name)
  output = ""
  if !File.directory?(dir_name)
    if $os_name.match(/SunOS/)
      message = "Warning:\t"+dir_name+" does not exist"
      if dir_name.match(/ldoms|zones/)
        zfs_name = $default_dpool+dir_name
      else
        zfs_name = $default_zpool+dir_name
      end
      command = "zfs create #{zfs_name}"
      output  = execute_command(message,command)
      if dir_name.match(/vmware/)
        service_name = File.basename(dir_name)
        mount_dir    = $tftp_dir+"/"+service_name
        message      = "Information:\tVMware repository being mounted under "+mount_dir
        command      = "zfs set mountpoint=#{mount_dir} #{zfs_name}"
        execute_command(message,command)
        message = "Information:\tSymlinking "+mount_dir+" to "+dir_name
        command = "ln -s #{mount_dir} #{dir_name}"
        execute_command(message,command)
      end
    else
      check_dir_exists(dir_name)
    end
  end
  return output
end

# Destroy a ZFS filesystem

def destroy_zfs_fs(dir_name)
  output = ""
  if $destroy_fs == 1
    if File.directory?(dir_name)
      message = "Warning:\tDestroying "+dir_name
      if dir_name.match(/ldoms|zones/)
        zfs_name = $default_dpool+dir_name
      else
        zfs_name = $default_zpool+dir_name
      end
      command = "zfs destroy -r #{zfs_name}"
      output  = execute_command(message,command)
    end
  end
  return output
end

# Routine to execute command
# Prints command if verbose switch is on
# Does not execute cerver/client import/create operations in test mode

def execute_command(message,command)
  output  = ""
  execute = 0
  if $verbose_mode == 1
    if message.match(/[A-z|0-9]/)
      puts message
    end
  end
  if $test_mode == 1
    if !command.match(/create|update|import|delete|svccfg|rsync|cp|touch|svcadm|VBoxManage|vmrun/)
      execute = 1
    end
  else
    execute = 1
  end
  if execute == 1
    if $id != 0
      if !command.match(/brew |hg|pip/)
        if $use_sudo != 0
          command = "sudo sh -c \""+command+"\""
        end
      end
    end
    if $verbose_mode == 1
      puts "Executing:\t"+command
    end
    output = %x[#{command}]
  end
  if $verbose_mode == 1
    if output.length > 1
      if !output.match(/\n/)
        puts "Output:\t\t"+output
      else
        multi_line_output = output.split(/\n/)
        multi_line_output.each do |line|
          puts "Output:\t\t"+line
        end
      end
    end
  end
  return output
end

# Convert current date to a string that can be used in file names

def get_date_string()
  time        = Time.new
  time        = time.to_a
  date        = Time.utc(*time)
  date_string = date.to_s.gsub(/\s+/,"_")
  date_string = date_string.gsub(/:/,"_")
  date_string = date_string.gsub(/-/,"_")
  if $verbose_mode == 1
    puts "Information:\tSetting date string to "+date_string
  end
  return date_string
end

# Create an encrypted password field entry for a give password

def get_password_crypt(password)
  crypt = UnixCrypt::MD5.build(password)
  return crypt
end

# Handle SMF service

def handle_smf_service(function,smf_service_name)
  if $os_name.match(/SunOS/)
    uc_function = function.capitalize
    if function.match(/enable/)
      message = "Checking:\tStatus of service "+smf_service_name
      command = "svcs #{smf_service_name} |grep -v STATE"
      output  = execute_command(message,command)
      if output.match(/maintenance/)
        message = uc_function+":\tService "+smf_service_name
        command = "svcadm clear #{smf_service_name} ; sleep 5"
        output  = execute_command(message,command)
      end
      if !output.match(/online/)
        message = uc_function+":\tService "+smf_service_name
        command = "svcadm #{function} #{smf_service_name} ; sleep 5"
        output  = execute_command(message,command)
      end
    else
      message = uc_function+":\tService "+smf_service_name
      command = "svcadm #{function} #{smf_service_name} ; sleep 5"
      output  = execute_command(message,command)
    end
  end
  return output
end

# Restart DHCPd

def restart_dhcpd()
  if $os_name.match(/SunOS/)
    function         = "refresh"
    smf_service_name = "svc:/network/dhcp/server:ipv4"
    output           = handle_smf_service(function,smf_service_name)
  else
    service_name = "dhcp"
    refresh_service(service_name)
  end
  return output
end

# Check DHPCPd is running

def check_dhcpd()
  message = "Checking:\tDHCPd is running"
  if $os_name.match(/SunOS/)
    command = "svcs -l svc:/network/dhcp/server:ipv4"
    output  = execute_command(message,command)
    if output.match(/maintenance/)
      function         = "refresh"
      smf_service_name = "svc:/network/dhcp/server:ipv4"
      output           = handle_smf_service(function,smf_service_name)
    end
  end
  if $os_name.match(/Darwin/)
    command = "ps aux |grep '/usr/local/bin/dhcpd' |grep -v grep"
    output  = execute_command(message,command)
    if !output.match(/dhcp/)
      service = "dhcp"
      check_osx_service_is_enabled(service)
      service_name = "dhcp"
      refresh_service(service_name)
    end
    check_osx_tftpd()
  end
  return output
end

# Disable SMF service

def disable_smf_service(smf_service_name)
  function = "disable"
  output   = handle_smf_service(function,smf_service_name)
  return output
end

# Enable SMF service

def enable_smf_service(smf_service_name)
  function = "enable"
  output   = handle_smf_service(function,smf_service_name)
  return output
end

# Refresh SMF service

def refresh_smf_service(smf_service_name)
  function = "refresh"
  output   = handle_smf_service(function,smf_service_name)
  return output
end

# Check SMF service

def check_smf_service(smf_service_name)
  if $os_name.match(/SunOS/)
    message = "Checking:\tService "+smf_service_name
    command = "svcs -a |grep '#{smf_service_name}"
    output  = execute_command(message,command)
  end
  return output
end

# Enable OS X service

def refresh_osx_service(service_name)
  if !service_name.match(/\./)
    if service_name.match(/dhcp/)
      service_name = "homebrew.mxcl.isc-"+service_name
    else
      service_name = "com.apple."+service_name+"d"
    end
  end
  disable_osx_service(service_name)
  enable_osx_service(service_name)
  return
end

# Enable OS X service

def enable_osx_service(service_name)
  check_osx_service_is_enabled(service_name)
  message = "Enabling:\tService "+service_name
  command = "launchctl start #{service_name}"
  output  = execute_command(message,command)
  return output
end

# Enable OS X service

def disable_osx_service(service_name)
  message = "Disabling:\tService "+service_name
  command = "launchctl stop #{service_name}"
  output  = execute_command(message,command)
  return output
end

# Get service name

def get_service_name(service_name)
  if $os_name.match(/SunOS/)
    if service_name.match(/apache/)
      service_name = "svc:/network/http:apache22"
    end
    if service_name.match(/dhcp/)
      service_name = "svc:/network/dhcp/server:ipv4"
    end
  end
  if $os_name.match(/Darwin/)
    if service_name.match(/apache/)
      service_name = "org.apache.httpd"
    end
    if service_name.match(/dhcp/)
      service_name = "homebrew.mxcl.isc-dhcp"
    end
  end
  if $os_name.match(/RedHat|CentOS|SuSE|Ubuntu/)
  end
  return service_name
end

# Enable service

def enable_service(service_name)
  service_name = get_service_name(service_name)
  if $os_name.match(/SunOS/)
    output = enable_smf_service(service_name)
  end
  if $os_name.match(/Darwin/)
    output = enable_osx_service(service_name)
  end
  return output
end

# Disable service

def disable_service(service_name)
  service_name = get_service_name(service_name)
  if $os_name.match(/SunOS/)
    output = disable_smf_service(service_name)
  end
  if $os_name.match(/Darwin/)
    output = disable_osx_service(service_name)
  end
  return output
end

# Refresh / Restart service

def refresh_service(service_name)
  service_name = get_service_name(service_name)
  if $os_name.match(/SunOS/)
    output = refresh_smf_service(service_name)
  end
  if $os_name.match(/Darwin/)
    output = refresh_osx_service(service_name)
  end
  return output
end

# Calculate route

def get_ipv4_default_route(client_ip)
  octets             = client_ip.split(/\./)
  octets[3]          = "254"
  ipv4_default_route = octets.join(".")
  return ipv4_default_route
end

# Create a ZFS filesystem for ISOs if it doesn't exist
# Eg /export/isos
# This could be an NFS mount from elsewhere
# If a directory already exists it will do nothing
# It will check that there are ISOs in the directory
# If none exist it will exit

def check_iso_base_dir(search_string)
  iso_list = []
  if $verbose_mode == 1
    puts "Checking:\t"+$iso_base_dir
  end
  check_zfs_fs_exists($iso_base_dir)
  message  = "Getting:\t"+$iso_base_dir+" contents"
  command  = "ls #{$iso_base_dir}/*.iso |egrep '#{search_string}'"
  iso_list = execute_command(message,command)
  if search_string.match(/sol_11/)
    if !iso_list.grep(/full/)
      puts "Warning:\tNo full repository ISO images exist in "+$iso_base_dir
      if $test_mode != 1
        exit
      end
    end
  end
  iso_list = iso_list.split(/\n/)
  return iso_list
end

# Check client architecture

def check_client_arch(client_arch)
  if !client_arch.match(/i386|sparc|x86_64/)
    puts "Warning:\tInvalid architecture specified"
    puts "Warning:\tUse -a i386, -a x86_64 or -a sparc"
    exit
  end
  return
end

# Client MAC check

def check_client_mac(client_mac)
  if !client_mac.match(/[0-9]/)
    puts "Warning:\tNo client MAC address given"
    exit
  end
  return
end

# Client IP check

def check_client_ip(client_ip)
  if !client_ip.match(/[0-9]/)
    puts "Warning:\tNo client IP address given"
    exit
  end
  return
end

# Add apache proxy

def add_apache_proxy(publisher_host,publisher_port,service_base_name)
  if $os_name.match(/SunOS/)
    apache_config_file = "/etc/apache2/2.2/httpd.conf"
  end
  if $os_name.match(/Darwin/)
    apache_config_file = "/etc/apache2/httpd.conf"
  end
  apache_check = %x[cat #{apache_config_file} |grep #{service_base_name}]
  if !apache_check.match(/#{service_base_name}/)
    message = "Archiving:\t"+apache_config_file+" to "+apache_config_file+".no_"+service_base_name
    command = "cp #{apache_config_file} #{apache_config_file}.no_#{service_base_name}"
    execute_command(message,command)
    message = "Adding:\t\tProxy entry to "+apache_config_file
    command = "echo 'ProxyPass /"+service_base_name+" http://"+publisher_host+":"+publisher_port+" nocanon max=200' >>"+apache_config_file
    execute_command(message,command)
    service_name = "apache"
    enable_service(service_name)
    refresh_service(service_name)
  end
  return
end

# Remove apache proxy

def remove_apache_proxy(service_base_name)
  if $os_name.match(/SunOS/)
    apache_config_file = "/etc/apache2/2.2/httpd.conf"
  end
  if $os_name.match(/Darwin/)
    apache_config_file = "/etc/apache2/httpd.conf"
  end
  message      = "Checking:\tApache confing file "+apache_config_file+" for "+service_base_name
  command      = "cat #{apache_config_file} |grep '#{service_base_name}'"
  apache_check = execute_command(message,command)
  if apache_check.match(/#{service_base_name}/)
    restore_file = apache_config_file+".no_"+service_base_name
    if File.exist?(restore_file)
      message = "Restoring:\t"+restore_file+" to "+apache_config_file
      command = "cp #{restore_file} #{apache_config_file}"
      execute_command(message,command)
      service_name = "apache"
      refresh_service(service_name)
    end
  end
end

# Add apache alias

def add_apache_alias(service_base_name)
  if service_base_name.match(/^\//)
    repo_version_dir  = service_base_name
    service_base_name = service_base_name.gsub(/^\//,"")
  else
    repo_version_dir = $repo_base_dir+"/"+service_base_name
  end
  if $os_name.match(/SunOS/)
    apache_config_file = "/etc/apache2/2.2/httpd.conf"
  end
  if $os_name.match(/Darwin/)
    apache_config_file = "/etc/apache2/httpd.conf"
  end
  tmp_file     = "/tmp/httpd.conf"
  message      = "Checking:\tApache confing file "+apache_config_file+" for "+service_base_name
  command      = "cat #{apache_config_file} |grep '#{service_base_name}'"
  apache_check = execute_command(message,command)
  if !apache_check.match(/#{service_base_name}/)
    message = "Archiving:\tApache config file "+apache_config_file+" to "+apache_config_file+".no_"+service_base_name
    command = "cp #{apache_config_file} #{apache_config_file}.no_#{service_base_name}"
    execute_command(message,command)
    if $verbose_mode == 1
      puts "Adding:\t\tDirectory and Alias entry to "+apache_config_file
    end
    message = "Copying:\tApache config file so it can be edited"
    command = "cp #{apache_config_file} #{tmp_file} ; chown #{$id} #{tmp_file}"
    execute_command(message,command)
    output = File.open(tmp_file,"a")
    output.write("<Directory #{repo_version_dir}>\n")
    if service_base_name.match(/oel/)
      output.write("Options Indexes FollowSymLinks\n")
    else
      output.write("Options Indexes\n")
    end
    output.write("Allow from #{$default_apache_allow}\n")
    output.write("</Directory>\n")
    output.write("Alias /#{service_base_name} #{repo_version_dir}\n")
    output.close
    message = "Updating:\tApache config file"
    command = "cp #{tmp_file} #{apache_config_file} ; rm #{tmp_file}"
    execute_command(message,command)
    service_name = "apache"
    enable_service(service_name)
    refresh_service(service_name)
  end
  return
end

# Remove apache alias

def remove_apache_alias(service_base_name)
  remove_apache_proxy(service_base_name)
end

# Mount full repo isos under iso directory
# Eg /export/isos
# An example full repo file name
# /export/isos/sol-11_1-repo-full.iso
# It will attempt to mount them
# Eg /cdrom
# If there is something mounted there already it will unmount it

def mount_iso(iso_file)
  puts "Processing:\t"+iso_file
  output  = check_dir_exists($iso_mount_dir)
  message = "Checking:\tExisting mounts"
  command = "df |awk '{print $1}' |grep '^#{$iso_mount_dir}$'"
  output=execute_command(message,command)
  if output.match(/[A-z]/)
    message = "Unmounting:\t"+$iso_mount_dir
    command = "umount "+$iso_mount_dir
    output  = execute_command(message,command)
  end
  message = "Mounting:\tISO "+iso_file+" on "+$iso_mount_dir
  if $os_name.match(/SunOS/)
    command = "mount -F hsfs "+iso_file+" "+$iso_mount_dir
  end
  if $os_name.match(/Darwin/)
    command = "hdiutil attach -nomount #{iso_file} |head -1 |awk '{print $1}'"
    if $verbose_mode == 1
      puts "Executing:\t"+command
    end
    disk_id = %x[#{command}]
    disk_id = disk_id.chomp
    command = "mount -t cd9660 "+disk_id+" "+$iso_mount_dir
  end
  if $os_name.match(/CentOS|RedHat|Ubuntu/)
    command = "mount -t iso9660 "+iso_file+" "+$iso_mount_dir
  end
  output = execute_command(message,command)
  if iso_file.match(/sol/)
    if iso_file.match(/\-ga\-/)
      iso_test_dir = $iso_mount_dir+"/boot"
    else
      iso_test_dir = $iso_mount_dir+"/repo"
    end
  else
    if iso_file.match(/CentOS|SL/)
      iso_test_dir = $iso_mount_dir+"/repodata"
    else
      if iso_file.match(/rhel|OracleLinux/)
        iso_test_dir = $iso_mount_dir+"/Packages"
      else
        if iso_file.match(/VM/)
          iso_test_dir = $iso_mount_dir+"/upgrade"
        else
          if iso_file.match(/SLES/)
            iso_test_dir = $iso_mount_dir+"/suse"
          else
            iso_test_dir = $iso_mount_dir+"/install"
          end
        end
      end
    end
  end
  if !File.directory?(iso_test_dir)
    puts "Warning:\tISO did not mount, or this is not a repository ISO"
    puts "Warning:\t"+iso_test_dir+" does not exit"
    if $test_mode != 1
      exit
    end
  end
  return
end

# Check ISO mounted for OS X based server

def check_osx_iso_mount(mount_dir,iso_file)
  check_dir_exists(mount_dir)
  test_dir = mount_dir+"/boot"
  if !File.directory?(test_dir)
    message = "Mounting:\ISO "+iso_file+" on "+mount_dir
    command = "hdiutil mount #{iso_file} -mountpoint #{mount_dir}"
    output  = execute_command(message,command)
  end
  return output
end

# Copy repository from ISO to local filesystem

def copy_iso(iso_file,repo_version_dir)
  puts "Checking:\tIf we can copy data from full repo ISO"
  if iso_file.match(/sol/)
    iso_repo_dir = $iso_mount_dir+"/repo"
    test_dir     = repo_version_dir+"/publisher"
  else
    iso_repo_dir = $iso_mount_dir
    if iso_file.match(/CentOS|rhel|OracleLinux/)
      test_dir = repo_version_dir+"/isolinux"
    else
      if iso_file.match(/VM/)
        test_dir = repo_version_dir+"/upgrade"
      else
        test_dir = repo_version_dir+"/install"
      end
    end
  end
  if !File.directory?(repo_version_dir) and !File.symlink?(repo_version_dir)
    puts "Warning:\tRepository directory "+repo_version_dir+" does not exist"
    if $test_mode != 1
      exit
    end
  end
  if !File.directory?(test_dir)
    if iso_file.match(/sol/)
      message = "Copying:\t"+iso_repo_dir+" contents to "+repo_version_dir
      command = "rsync -a #{iso_repo_dir}/* #{repo_version_dir}"
      output  = execute_command(message,command)
      if $os_name.match(/SunOS/)
        message = "Rebuilding:\tRepository in "+repo_version_dir
        command = "pkgrepo -s #{repo_version_dir} rebuild"
        output  = execute_command(message,command)
      end
    else
      check_dir_exists(test_dir)
      message = "Copying:\t"+iso_repo_dir+" contents to "+repo_version_dir
      command = "rsync -a #{iso_repo_dir}/* #{repo_version_dir}"
      output  = execute_command(message,command)
    end
  end
  return
end

# Unmount ISO

def umount_iso()
  if $os_name.match(/Darwin/)
    command = "df |grep '#{$iso_mount_dir}$' |head -1 |awk '{print $1}'"
    if $verbose_mode == 1
      puts "Executing:\t"+command
    end
    disk_id = %x[#{command}]
    disk_id = disk_id.chomp
  end
  message = "Unmounting:\tISO mounted on "+$iso_mount_dir
  command = "umount #{$iso_mount_dir}"
  execute_command(message,command)
  if $os_name.match(/Darwin/)
    message = "Detaching:\tISO device "+disk_id
    command = "hdiutil detach #{disk_id}"
    execute_command(message,command)
  end
  return
end
