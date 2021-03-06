#!/usr/bin/env ruby

# Name:         modest (Multi OS Deployment Engine Server Tool)
# Version:      2.0.3
# Release:      1
# License:      CC-BA (Creative Commons By Attribution)
#               http://creativecommons.org/licenses/by/4.0/legalcode
# Group:        System
# Source:       N/A
# URL:          http://lateralblast.com.au/
# Distribution: UNIX
# Vendor:       Lateral Blast
# Packager:     Richard Spindler <richard@lateralblast.com.au>
# Description:  Script to automate creation of server configuration for
#               Solaris and other OS

# Additional notes:
#
# - Swapped Dir.exits for File.directory so ruby 2.x is not required
# - Swapped Dir.home for ENV["HOME"] so ruby 2.x is not required

require 'rubygems'
require 'getopt/std'
require 'builder'
require 'socket'
require 'parseconfig'
require 'unix_crypt'
require 'pathname'
require 'netaddr'
require 'net/http'
require 'uri'
require 'nokogiri'
require 'mechanize'

# Set up some global variables/defaults

$script                 = $0
$options                = "a:b:c:d:e:f:g:h:i:j:k:l:m:n:o:p:q:r:s:x:z:ABCDEFGHIJKLMNOPQRSTUVWXYZtuvwy120"
$verbose_mode           = 0
$test_mode              = 0
$download_mode          = 1
$iso_base_dir           = "/export/isos"
$repo_base_dir          = "/export/repo"
$image_base_dir         = "/export/images"
$pkg_base_dir           = "/export/pkgs"
$ldom_base_dir          = "/ldoms"
$zone_base_dir          = "/zones"
$iso_mount_dir          = "/cdrom"
$ai_base_dir            = "/export/auto_install"
$client_base_dir        = "/export/clients"
$lxc_base_dir           = "/lxc"
$lxc_image_dir          = "/export/images"
$work_dir               = ""
$tmp_dir                = ""
$alt_repo_name          = "alt"
$alt_prefix_name        = "solaris"
$home_dir               = ENV["HOME"]
$dhcpd_file             = "/etc/inet/dhcpd4.conf"
$fusion_dir             = ""
$default_zpool          = "rpool"
$default_ai_port        = "10081"
$default_host           = ""
$default_hostname       = %x["hostname"].chomp
$default_nic            = ""
$default_net            = "net0"
$default_timezone       = "Australia/Victoria"
$default_terminal       = "sun"
$default_country        = "AU"
$local_opencsw_mirror   = "http://192.168.1.250/pub/Software/OpenCSW"
$default_opencsw        = "testing"
$default_ubuntu_mirror  = $default_country.downcase+".archive.ubuntu.com"
$default_centos_mirror  = "mirror.centos.org"
$default_sl_mirror      = "ftp.scientificlinux.org/linux"
$default_epel_mirror    = "download.fedoraproject.org"
$local_sl_mirror        = "mirror.aarnet.edu.au/pub"
$local_ubuntu_mirror    = "mirror.aarnet.edu.au"
$local_centos_mirror    = "mirror.aarnet.edu.au/pub"
$local_epel_mirror      = "mirror.aarnet.edu.au"
$default_timeserver     = "0."+$default_country.downcase+".pool.ntp.org"
$default_keymap         = "US-English"
$default_environment    = "en_US.UTF-8"
$default_language       = "en_US"
$default_system_locale  = "C"
$default_nameserver     = "8.8.8.8"
$default_name_service   = "none"
$default_security       = "none"
$default_netmask        = "255.255.255.0"
$default_domain         = "local"
$default_search         = "local"
$default_files          = "files"
$default_hosts          = "files dns"
$default_root_password  = "XXXX"
$default_admin_password = "YYYY"
$default_maas_admin     = "root"
$default_maas_email     = $default_maas_admin+"@"+$default_host
$default_mass_password  = $default_admin_password
$use_alt_repo           = 0
$destroy_fs             = "n"
$use_defaults           = 0
$default_apache_allow   = ""
$default_admin_name     = "Sys Admin"
$default_admin_user     = "sysadmin"
$default_admin_group    = "wheel"
$default_admin_home     = "/home/"+$default_admin_user
$default_admin_shell    = "/bin/bash"
$default_admin_uid      = "200"
$default_admin_gid      = "200"
$preseed_admin_uid      = "1000"
$preseed_admin_gid      = "1000"
$tftp_dir               = "/etc/netboot"
$default_cluster        = "SUNWCprog"
$default_install        = "initial_install"
$default_nfs4_domain    = "dynamic"
$default_auto_reg       = "disable"
$q_struct               = {}
$q_order                = []
$text_mode              = 1
$backup_dir             = ""
$rpm2cpio_url           = "http://svnweb.freebsd.org/ports/head/archivers/rpm2cpio/files/rpm2cpio?revision=259745&view=co"
$rpm2cpio_bin           = ""
$vbox_disk_type         = "sas"
$default_vm_size        = "12G"
$default_vm_mem         = "1024"
$default_vm_vcpu        = "1"
$serial_mode            = 0
$os_name                = ""
$yes_to_all             = 0
$default_cdom_mau       = "1"
$default_gdom_mau       = "1"
$default_cdom_vcpu      = "8"
$default_gdom_mem       = "4G"
$default_gdom_vcpu      = "8"
$default_gdom_mem       = "4G"
$default_gdom_size      = "10G"
$default_cdom_name      = "initial"
$default_dpool          = "dpool"
$default_gdom_vnet      = "vnet0"
$use_sudo               = 1
$do_ssh_keys            = 0
$default_vm_network     = "hostonly"
$default_vm_hw_version  = "8"
$default_hostonly_ip    = "192.168.2.254"
$default_server_size    = "small"
$default_manifest_name  = "modest"
$vbox_additions_iso     = "/Applications/VirtualBox.app//Contents/MacOS/VBoxGuestAdditions.iso"
$openbsd_base_url       = "http://ftp.openbsd.org/pub/OpenBSD"
$default_x86_virtual    = "VirtualBox"
$default_x86_vm_net     = "enp0s3"
$default_ext_network    = "192.168.1.0"
$puppet_rpm_base_url    = "http://yum.puppetlabs.com"
$centos_rpm_base_url    = "http://"+$local_centos_mirror+"/centos"
$default_vm_utc         = "off"

# Declare some package versions

$facter_version = "1.7.4"
$hiera_version  = "1.3.1"
$puppet_version = "3.4.2"

# Calculate CIDR

def netmask_to_cidr(netmask)
  cidr = NetAddr::CIDR.create('0.0.0.0/'+netmask).netmask
  return cidr
end

$default_cidr = netmask_to_cidr($default_netmask)

# Load methods

if File.directory?("./methods")
  file_list = Dir.entries("./methods")
  for file in file_list
    if file =~ /rb$/
      require "./methods/#{file}"
    end
  end
end

# Create required directories

check_dir_exists($work_dir)
[ $iso_base_dir, $repo_base_dir, $image_base_dir, $pkg_base_dir, $client_base_dir ].each do |dir_name|
  check_zfs_fs_exists(dir_name)
end

# Print script usage information

def print_usage()
  puts ""
  puts "Usage: "+$script+" -["+$options+"]"
  puts ""
  puts "-h: Display usage"
  puts "-c: Create client"
  puts "-V: Display version"
  puts "-A: Configure AI"
  puts "-J: Configure Jumpstart"
  puts "-K: Configure Kickstart (CentOS and RedHat)"
  puts "-U: Configure Preseed (Ubuntu)"
  puts "-Y: Configure AutoYast (SuSE)"
  puts "-E: Configure VSphere"
  puts "-Z: Configure Zone"
  puts "-M: Configure MAAS"
  puts "-B: Configure BSD"
  puts "-G: Maintenance mode"
  puts "-a: Architecture"
  puts "-e: Client MAC Address"
  puts "-i: Client IP Address"
  puts "-m: Client model (used for Jumpstart)"
  puts "-S: Configure server (or snapshot VMs when dealing with VMs)"
  puts "-C: Configure client services (or clone VM when dealing with VMs)"
  puts "-O: Configure VirtualBox VM"
  puts "-F: Configure VMware Fusion VM"
  puts "-o: Specify OS type (used when creating VMs)"
  puts "-r: Specify OS release (used when creating VMs)"
  puts "-b: Boot VM"
  puts "-s: Stop VM"
  puts "-g: Halt VM"
  puts "-p: Puplisher server port number (or connect to virtual serial port when dealing with VMs)"
  puts "-l: Puplisher server Hostname/IP"
  puts "-t: Run it test mode"
  puts "-v: Run in verbose mode"
  puts "-f: ISO or or OVA file to import or export"
  puts "-d: Delete client"
  puts "-n: Set service name (or set new name when dealing with cloning VMs)"
  puts "-z: Delete service name"
  puts "-P: Configure PXE"
  puts "-W: Update apache proxy entry for AI (or export OVA when used dealing with VMs)"
  puts "-R: Use alternate package repository (or show running VMs when dealing with VMs)"
  puts "-y: Override (destroy ZFS filesystem as part of uninstallation and delete clients)"
  puts "-D: Use default values for questions"
  puts "-T: Use text mode install"
  puts "-2: Use serial connectivity (emulated)"
  puts "-X: X Windows based install (default is text based)"
  puts "    or run VM in GUI mode (default is headless)"
  puts "-H: Provide detailed examples"
  puts "-Q: Copy SSH keys"
  puts "-k: Set VMware Fusion or VirtualBox networking type (e.g. bridged or hostonly)"
  puts "-w: Disable downloads"
  puts "-x: Set VM network type (e.g. hostonly or bridged or nat)"
  puts "-q: Set server size for client (e.g. small or large)"
  puts "-1: Check local configuration"
  puts "-2: Enable serial mode"
  puts "-0: Check server functions on OS X"
  puts "-u: Specify username"
  puts "-I: Handle ISOs or OVAs"
  puts
  exit
  return
end

# Get version

def get_version()
  file_array = IO.readlines $0
  version    = file_array.grep(/^# Version/)[0].split(":")[1].gsub(/^\s+/,'').chomp
  packager   = file_array.grep(/^# Packager/)[0].split(":")[1].gsub(/^\s+/,'').chomp
  name       = file_array.grep(/^# Name/)[0].split(":")[1].gsub(/^\s+/,'').chomp
  return version,packager,name
end

# Print script version information

def print_version()
  (version,packager,name) = get_version()
  puts name+" v. "+version+" "+packager
  exit
end

# Generate a client MAC address if not given one

def create_client_mac(client_mac)
  if !client_mac.match(/[0-9]/)
    client_mac = (1..6).map{"%0.2X"%rand(256)}.join(":")
    if $verbose_mode == 1
      puts "Information:\tGenerated MAC address "+client_mac
    end
  end
  return client_mac
end

# Check local configuration
# Create work directory if it doesn't exist
# If not running on Solaris, run in test mode
# Useful for generating client config files

def check_local_config(mode,opt)
  if $do_ssh_keys == 1
    check_ssh_keys()
  end
  if $verbose_mode == 1
    puts "Information:\tHome directory "+$home_dir
  end
  $id=%x[/usr/bin/id -u]
  $id=Integer($id)
  if !$work_dir.match(/[A-z]/)
    dir_name = File.basename($script,".*")
    if $id == 0
      $work_dir = "/opt/"+dir_name
    else
      $work_dir = $home_dir+"/."+dir_name
    end
  end
  if $verbose_mode == 1
    puts "Information:\tSetting work directory to "+$work_dir
  end
  if !$tmp_dir.match(/[A-z]/)
    $tmp_dir = $work_dir+"/tmp"
  end
  if $verbose_mode == 1
    puts "Information:\tSetting temporary directory to "+$work_dir
  end
  # Get OS name and set system settings appropriately
  check_dir_exists($work_dir)
  check_dir_owner($work_dir,$id)
  check_dir_exists($tmp_dir)
  $os_name = %x[uname].chomp
  $os_arch = %x[uname -p].chomp
  $os_mach = %x[uname -m].chomp
  if $os_name.match(/SunOS|Darwin/)
    $os_info = %x[uname -a].chomp
    $os_rel  = %x[uname -r].chomp
    if $os_rel.match(/5\.11/) and $os_name.match(/SunOS/)
      $os_update   = %x[uname -v].chomp
      $default_net = "net0"
    end
  else
    $os_info = %x[lsb_release -i].chomp
  end
  if $os_name.match(/Linux/)
    $os_rel = %x[lsb_release -r |awk '{print $2}'].chomp
  end
  if $os_info.match(/Ubuntu/)
    $lxc_base_dir = "/var/lib/lxc"
  end
  if !$default_host.match(/[0-9]/)
    message = "Determining:\tDefault host IP"
    if $os_name.match(/SunOS/)
      command = "ipadm show-addr #{$default_net} |grep net |head -1 |awk '{print $4}' |cut -f1 -d'/'"
    end
    if $os_name.match(/Darwin/)
      $default_net="en0"
      command = "ifconfig #{$default_net} |grep 'inet ' |awk '{print $2}'"
    end
    if $os_name.match(/Linux/)
      $default_net="eth0"
      command = "ifconfig #{$default_net} |grep 'inet ' |awk '{print $2}'"
      test_ip = %x[#{command}].chomp
      if !test_ip.match(/inet/)
        command = "ifconfig lxcbr0 |grep 'inet ' |awk '{print $2}'"
      end
    end
    $default_host = execute_command(message,command)
    $default_host = $default_host.chomp
    if $default_host.match(/inet/)
      $default_host = $default_host.gsub(/^\s+/,"").split(/\s+/)[1]
    end
  end
  if !$default_apache_allow.match(/[0-9]/)
    if $default_ext_network.match(/[0-9]/)
      $default_apache_allow = $default_host.split(/\./)[0..2].join(".")+" "+$default_ext_network
    else
      $default_apache_allow = $default_host.split(/\./)[0..2].join(".")
    end
  end
  if mode == "server"
    if $os_name == "Darwin"
      $tftp_dir   = "/private/tftpboot"
      $dhcpd_file = "/usr/local/etc/dhcpd.conf"
    end
    if $os_name.match(/SunOS/) and $os_rel.match(/11/)
      check_tftpd()
      check_local_publisher()
      install_sol11_pkg("pkg:/system/boot/network")
      install_sol11_pkg("installadm")
      install_sol11_pkg("lftp")
    end
    if $verbose_mode == 1
      puts "Information:\tSetting apache allow range to "+$default_apache_allow
    end
    if $os_name.match(/SunOS/)
      check_sol_puppet()
      check_sol_bind()
    end
    if $os_name.match(/Linux/)
      if $os_info.match(/RedHat|CentOS/)
        check_yum_tftpd()
        check_yum_dhcpd()
        $tftp_dir   = "/tftpboot"
        $dhcpd_file = "/etc/dhcpd.conf"
      else
        check_apt_tftpd()
        check_apt_dhcpd()
        $tftp_dir   = "/tftpboot"
        $dhcpd_file = "/etc/dhcp/dhcpd.conf"
      end
    end
  else
    if $os_name.match(/Linux/)
      if $os_info.match(/RedHat|CentOS/)
        $tftp_dir   = "/tftpboot"
        $dhcpd_file = "/etc/dhcpd.conf"
      else
        $tftp_dir   = "/tftpboot"
        $dhcpd_file = "/etc/dhcp/dhcpd.conf"
      end
    end
    if $os_name.match(/Darwin/)
      $tftp_dir   = "/private/tftpboot"
      $dhcpd_file = "/usr/local/etc/dhcpd.conf"
    end
  end
  # If runnning on OS X check we have brew installed
  if $os_name.match(/Darwn/)
    if !File.exists?("/usr/local/bin/brew")
      message = "Installing:\tBrew for OS X"
      command = "ruby -e \"$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)\""
      execute_command(message,command)
    end
  end
  # Set location of VMware Fusion and VirtualBox VMs
  if $os_name.match(/Darwin/)
    $fusion_dir=$home_dir+"/Documents/Virtual Machines.localized"
    if !File.directory?($fusion_dir)
      $fusion_dir=$home_dir+"/Documents/Virtual Machines"
    end
  end
  $backup_dir = $work_dir+"/backup"
  check_dir_exists($backup_dir)
  bin_dir     = $work_dir+"/bin"
  check_dir_exists(bin_dir)
  $rpm2cpio_bin=bin_dir+"/rpm2cpio"
  if !File.exist?($rpm2cpio_bin)
    if $download_mode == 1
      message = "Fetching:\tTool rpm2cpio"
      command = "wget '#{$rpm2cpio_url}' -O #{$rpm2cpio_bin} ; chown #{$id} #{$rpm2cpio_bin} ; chmod +x #{$rpm2cpio_bin}"
      execute_command(message,command)
      system("chmod +x #{$rpm2cpio_bin}")
    end
  end
  return
end

# Get command line arguments
# Print help if given none

if !ARGV[0]
  print_usage()
end

begin
  opt = Getopt::Std.getopts($options)
rescue
  print_usage()
end

if opt["u"]
  $default_admin_user = opt["u"]
end

if opt["0"]
  if $os_name.match(/Darwin/)
    check_osx_dnsmasq()
    check_osx_tftpd()
    check_osx_dhcpd()
    check_osx_puppet()
  end
end

# Set default network so that VMware and VirtualBox VMs can run at the same time

if opt["O"]
  $default_hostonly_ip = "192.168.2.254"
end

if opt["F"]
  $default_hostonly_ip = "192.168.2.1"
end

# Set vmrun bin

if opt["F"]
  set_vmrun_bin()
end

if opt["1"]
  mode = "server"
  check_local_config(mode,opt)
  if opt["F"] or opt["O"]
    if opt["F"]
      if_name = "vmnet1"
    end
    if opt["O"]
      if_name = "vboxnet0"
    end
    gw_if_name = get_osx_gw_if_name()
    if opt["O"]
      check_vbox_hostonly_network()
    end
    if opt["F"]
      check_fusion_hostonly_network(if_name)
    end
    check_osx_nat(gw_if_name,if_name)
  end
  exit
end

# If given -x set network type

if opt["x"]
  $default_vm_network = opt["x"]
end

# If given -q set server size

if opt["q"]
  $default_server_size = opt["q"]
end

# If we building ESX set default memory to 4G and 2 vCPUs

if opt["E"]
  configure_vmware_esxi_defaults()
end

# Enable / Disable downloads

if opt["w"]
  $download_mode = 0
else
  $download_mode = 1
end

# Change VM disk size

if opt["j"]
  $default_vm_size = opt["j"]
  if !$default_vm_size.match(/G$/)
    $default_vm_size = $default_vm_size+"G"
  end
end

# Connect to VirtualBox or VMware Fusion console

if opt["O"] or opt["F"] and opt["p"]
  client_name = opt["p"]
  connect_to_virtual_serial(client_name)
  exit
end

# Print examples

if opt["H"]
  $os_name = %x[uname]
  $os_arch = %x[uname -p]
  if opt["G"]
    examples = "maint"
  end
  if opt["S"]
    examples = "server"
  end
  if opt["O"]
    if $os_arch.match(/sparc/)
      examples = "ldom"
    else
      examples = "vbox"
    end
  end
  if opt["F"]
    check_promisc_mode()
    examples = "fusion"
  end
  if opt["C"]
    examples = "client"
  end
  if opt["V"]
    examples = "vbox"
  end
  if opt["I"]
    examples = "iso"
  end
  if opt["A"]
    examples = "ai"
  end
  if opt["K"]
    examples = "ks"
  end
  if opt["J"]
    examples = "js"
  end
  if opt["U"]
    examples = "ps"
  end
  if opt["E"]
    examples = "vs"
  end
  if opt["Y"]
    examples = "ay"
  end
  if opt["B"] or opt["N"]
    examples = "xb"
  end
  if opt["Z"]
    if $os_name.match(/SunOS/)
      examples = "zone"
    else
      examples = "lxc"
    end
  end
  if !examples
    examples = "all"
    print_examples(examples)
  else
    print_examples(examples)
  end
  exit
end

# Get password crypt
if opt["p"] and !opt["S"] and !opt["C"]
  password = opt["p"]
  crypt    = get_password_crypt(password)
  puts crypt
  exit
end

# If given -Q copy SSH keys

if opt["Q"]
  $do_ssh_keys = 1
end

# Print version

if opt["V"]
  print_version()
  exit
end

# Prient usage

if opt["h"]
  print_usage()
end

# Enable verbose mode

if opt["v"]
  $verbose_mode = 1
  puts "Information:\tRunning in verbose mode"
end

# Enable test mode

if opt["t"]
  $test_mode = 1
  puts "Information:\tRunning in test mode"
end

# Get/set publisher port

if opt["p"]
  publisher_port = opt["p"]
else
  publisher_port = $default_ai_port
end

# Verbose output

if $verbose_mode == 1 and !opt["I"]
   puts "Information:\tSetting publisher host to "+publisher_port
end

# Get MAC address if given

if opt["e"]
  client_mac = opt["e"]
  if $verbose_mode == 1
     puts "Information:\tClient ethernet MAC address is "+client_mac
  end
else
  client_mac = ""
end

# Get IP address if given

if opt["i"]
  client_ip = opt["i"]
  check_client_ip(client_ip)
  if $verbose_mode == 1
     puts "Information:\tClient IP address is "+client_ip
  end
else
  client_ip = ""
end

# Get/set service name

if opt["n"]
  service_name = opt["n"]
  if !service_name.match(/^[A-z]/)
    puts "Warning:\tService name must start with letter"
  end
else
  if !opt["z"]
    service_name = ""
  end
end

# Get architecture if given

if opt["a"]
  client_arch = opt["a"]
  client_arch = client_arch.downcase
  if client_arch.match(/sun4u|sun4v/)
  client_arch = "sparc"
  end
  if $verbose_mode == 1
     puts "Information:\tSetting architecture to "+client_arch
  end
else
  client_arch = ""
end

# Show running VMs

if opt["O"] or opt["F"] and opt["R"]
  if opt["O"]
    vfunct = "vbox"
  else
    vfunct = "fusion"
  end
  eval"[list_running_#{vfunct}_vms]"
  exit
end

# Check NAT and host configuration

if opt["G"]
  test_arch = %x[uname -p].chomp
  if opt ["O"] or opt["F"] and test_arch.match(/i386|x86_64/)
    if opt["O"]
      vfunct = "vbox"
    else
      vfunct = "fusion"
    end
    mode = "client"
    check_local_config(mode,opt)
    eval"[check_#{vfunct}_natd]"
    exit
  end
  if opt["C"]
    mode = "client"
    check_local_config(mode,opt)
    if opt["c"]
      client_name = opt["c"]
      if opt["i"]
        add_hosts_entry(client_name,client_ip)
      end
      if opt["e"]
        service_name = ""
        add_dhcp_client(client_name,client_mac,client_ip,client_arch,service_name)
      end
      exit
    end
    if opt["d"]
      client_name = opt["d"]
      remove_hosts_entry(client_name,client_ip)
      remove_dhcp_client(client_name)
      exit
    end
  end
end

# Check local configuration

if opt["S"] or opt["W"] or opt["G"] and !opt["O"] and !opt["F"]
  mode = "server"
else
  mode = "client"
end
if $verbose_mode == 1
  puts "Information     Running in "+mode+" mode"
end
check_local_config(mode,opt)

# Get/set publisher host

if opt["l"]
  publisher_host = opt["l"]
else
  publisher_host = $default_host
end


# If given -y assume yes to all questions

if opt["y"]
  $yes_to_all = 1
  $destroy_fs = "y"
  if $verbose_mode == 1
    if $os_name =~ /SunOS/
      puts "Warning:\tDestroying ZFS filesystems"
    end
  end
end

# Set VMware Fusion or VirtualBox networking type

if opt["k"]
  $vm_network_type = opt["k"]
end

# Get OS type

if opt["o"]
  client_os = opt["o"]
else
  client_os = ""
end

if !opt["c"] and !opt["S"] and !opt["d"] and !opt["z"] and !opt["W"] and !opt["C"] and !opt["R"] and !opt["L"] and !opt["P"] and !opt["O"] and !opt["F"] and !opt["Z"] and !opt["G"]
  puts "Warning:\tClient name not given"
  exit
else
  if opt["c"]
    client_name  = opt["c"]
  end
  if opt["d"]
    client_name  = opt["d"]
  end
  if opt["z"]
    service_name = opt["z"]
  end
  if opt["n"]
    service_name = opt["n"]
  end
  if opt["b"]
    client_name  = opt["b"]
  end
  if opt["s"]
    client_name  = opt["s"]
  end
  if opt["c"] or opt["d"] or opt["b"] or opt["s"]
    if $verbose_mode == 1
      puts "Information:\tSetting client name to "+client_name
    end
  end
  if opt["z"] or opt["n"]
    if $verbose_mode == 1
      puts "Information:\tSetting service name to "+service_name
    end
  end
end

# Get/set X based installer

if !opt["d"]
  if opt["X"]
    $text_mode = 0
    if $verbose_mode == 1
      puts "Information:\tRunning in windowed mode"
    end
  else
    $text_mode = 1
    if $verbose_mode == 1
      puts "Information:\tNot running in windowed mode"
    end
  end
end

# Get ISO file if given

if opt["f"]
  if !opt["Z"] and !opt["C"]
    iso_file = opt["f"]
    if $verbose_mode == 1
      puts "Information:\tUsing ISO "+iso_file
    end
  else
    image_file = opt["f"]
    if $verbose_mode == 1
      puts "Information:\tUsing Image "+image_file
    end
  end
else
  if opt["Z"]
    image_file = ""
  else
    iso_file = ""
  end
end

# If given -R use alternate repos

if opt["R"]
  $use_alt_repo = 1
else
  $use_alt_repo  = 0
end

# If given -D choose defaults for questions

if opt["D"]
  $use_defaults = 1
  if $verbose_mode == 1
    puts "Information:\tSetting answers to defaults"
  end
end

# If give a -T use text base install

if opt["T"]
  $text_mode = 1
end

# If given -2 use serial based install

if opt["2"]
  $text_mode = 1
  $serial_mode   = 1
  if $verbose_mode == 1
    puts "Information:\tUse serial connectivity"
  end
end

# Get/set system model

if opt["m"]
  if !opt["O"] and !$os_name.match(/sparc/)
    client_model = opt["m"]
    client_model = client_model.downcase
  end
else
  if !opt["S"]
    if opt["J"] and !opt["L"] and !opt["d"]
      if client_arch.match(/i386|x86|x86_64|x64/)
        puts "Warning:\tNo client architecture specified"
        puts "Setting:\tClient model to vmware"
        client_model = "vmware"
      else
        puts "Warning:\tClient model not specified"
        exit
      end
    else
      client_model = ""
    end
  end
end

# If given option O or F do VM related functions

if opt["O"]
  if $os_arch.match(/i386|x86_64/)
    $default_vm_size = $default_vm_size.gsub(/G/,"000")
    $use_sudo     = 0
    vfunct        = "vbox"
    if $verbose_mode == 1
      puts "Information:\tNot using sudo"
    end
  else
    if opt["S"]
      vfunct = "cdom"
    else
      vfunct = "gdom"
    end
  end
end

if opt["F"]
  if $verbose_mode == 1
    puts "Information:\tNot using sudo"
  end
  $use_sudo = 0
  vfunct    = "fusion"
end

# List appliances

if opt["O"] or opt["F"]
  if $os_arch.match(/i386|x86_64/)
    if opt["I"] or opt["W"]
      if opt["L"]
        list_ovas()
        exit
      end
      if opt["f"]
        if opt["F"]
          set_ovftool_bin()
        end
        ova_file = opt["f"]
        if opt["c"]
          client_name = opt["c"]
        else
          client_name = ""
        end
        if opt["I"]
          eval"[import_#{vfunct}_ova(client_name,client_mac,client_ip,ova_file)]"
        end
        if opt["W"]
          eval"[export_#{vfunct}_ova(client_name,ova_file)]"
        end
        exit
      end
      if opt["C"]
        if !opt["c"] or !opt["n"]
          puts "VM name not specified"
        end
        client_name = opt["c"]
        new_name    = opt["n"]
        eval"[clone_#{vfunct}_vm(client_name,new_name,client_mac,client_ip)]"
        exit
      end
    end
  end
end

# VirtualBox and VMware Fusion functions (not create)

if opt["O"] or opt["F"] and $os_arch.match(/i386|x86_64/)
  if opt ["L"]
    search_string = ""
    if opt["c"]
      search_string = opt["c"]
    end
    if opt["e"]
      search_string = opt["e"]
    end
    eval"[list_#{vfunct}_vms(search_string)]"
  end
  if opt["b"]
    client_name = opt["b"]
    eval"[boot_#{vfunct}_vm(client_name)]"
    exit
  end
  if opt["s"]
    client_name = opt["s"]
    eval"[stop_#{vfunct}_vm(client_name)]"
    exit
  end
  if opt["d"]
    remove_hosts_entry(client_name,client_ip)
    eval"[unconfigure_#{vfunct}_vm(client_name)]"
  end
  if opt["e"]
    client_mac = opt["e"]
    client_mac = check_client_mac(client_mac)
    eval"[change_#{vfunct}_vm_mac(client_name,client_mac)]"
  end
end

# Set LXC server type

if opt["t"]
  server_type = opt["t"]
else
  server_type = "public"
end

# Force architecture

if opt["E"] or opt["B"]
  if opt["E"]
    client_arch = "x86_64"
  end
  if opt["B"]
    client_arch = "i386"
  end
  if $verbose_mode == 1
    puts "Setting:\tArchitecture to "+client_arch
  end
end

# If given -r set OS release

if opt["r"] and opt["Z"]
  client_rel = opt["r"]
  if $verbose_mode == 1
    puts "Setting:\tOperating System version of container to "+client_rel
  end
else
  if opt["Z"]
    client_rel = $os_rel
    if $verbose_mode == 1
      puts "Setting:\tOperating System version of container to same as host ["+$os_rel+"]"
    end
  end
end

# If given -Z (Zones) make sure we are running on Solaris
# If given -O (LDoms) make sure we are on T series

if opt["Z"]
  if !$os_name.match(/SunOS|Linux/)
    puts "Warning:\tContainers can only be created on Solaris (Zones) or Linux (LXC)"
    exit
  else
    if $os_name.match(/SunOS/)
      vfunct = "zone"
      if opt["r"]
        if client_rel.match(/11/) and $client_rel.match(/10/)
          puts "Warning:\tCannot create Solaris 11 Zones on Solaris 10"
          exit
        end
      end
    else
      vfunct = "lxc"
    end
  end
end

# Handle Zones/Containers and LDoms

if opt["Z"] and !opt["S"]
  if opt["O"] and !$os_arch.match(/i386|x86_64/)
    if opt["O"] and !$os_mach.match(/sun4v/)
      puts "Warning:\tArchitecture does not support LDoms"
      exit
    end
  end
  if opt["c"]
    if !$os_arch.match(/i386|x86_64/)
      eval"[configure_#{vfunct}(client_name,client_ip,client_mac,client_arch,client_os,client_rel,publisher_host,image_file,service_name)]"
    end
  end
  if opt["L"]
    eval"[list_#{vfunct}s()]"
  end
  if opt["b"]
    client_name = opt["b"]
    eval"[boot_#{vfunct}(client_name)]"
  end
  if opt["s"]
    client_name = opt["s"]
    eval"[stop_#{vfunct}(client_name)]"
  end
  if opt["g"]
    client_name = opt["g"]
    eval"[halt_#{vfunct}(client_name)]"
    exit
  end
  if opt["p"]
    client_name = opt["p"]
    eval"[execute_#{vfunct}_post(client_name)]"
  end
  if opt["d"]
    eval"[unconfigure_#{vfunct}(client_name)]"
  end
  exit
end

# If client configuration is being done, ensure there is a service name and a client architecture

if opt["C"] and !opt["d"] and !opt["L"]
  if !opt["n"]
    puts "Warning:\tService name not specified"
    exit
  end
  if !opt["a"] and !client_arch.match(/[A-z]/)
    puts "Warning:\tClient architecture not specified"
    exit
  end
end

# Handle AI, Jumpstart, Kickstart/Preseed, ESXi, and PE

if opt["A"] or opt["K"] or opt["J"] or opt["E"] or opt["G"] or opt["U"] or opt["Y"] or opt["S"] or opt["Z"] or opt["O"] or opt["B"]
  # Set function
  if opt["A"]
    funct = "ai"
  end
  if opt["K"]
    funct = "ks"
  end
  if opt["Y"]
    funct = "ay"
  end
  if opt["U"]
    funct = "ps"
  end
  if opt["J"]
    funct = "js"
  end
  if opt["E"]
    funct = "vs"
  end
  if opt["W"]
    funct = "pe"
  end
  if opt["B"] or opt["N"]
    funct = "xb"
  end
  if opt["Z"]
    if $os_name.match(/SunOS/)
      funct = "zone"
    else
      funct = "lxc"
    end
  end
  if !funct
    puts "Warning:\tNo VM type specified"
    exit
  end
  if opt["O"] or opt["F"] and $os_arch.match(/i386|x86_64/)
    if opt["c"]
      client_arch = check_client_arch(client_arch,opt)
      if !opt["O"]
        client_mac = create_client_mac(client_mac)
        client_mac = check_client_mac(client_mac)
      end
      if opt["B"]
        funct = "ob"
      end
      if opt["N"]
        funct = "nb"
      end
      if opt["i"]
        add_hosts_entry(client_name,client_ip)
      end
      eval"[configure_#{funct}_#{vfunct}_vm(client_name,client_mac,client_arch,client_os,client_rel)]"
      puts
      puts "To connect to the serial console of this machine once booted run the following command:"
      puts
      puts "socat UNIX-CONNECT:/tmp/#{client_name} STDIO,raw,echo=0,escape=0x11,icanon=0"
      puts
      puts "If you wish to disconnect from this session use CTRL-Q"
      puts
    end
    if opt["L"]
      eval"[list_#{funct}_#{vfunct}_vms()]"
    end
    exit
  end
  # Handle server related functions
  if opt ["S"]
    # Handle MAAS
    if opt["M"]
      configure_maas()
    end
    if opt["O"] and $os_arch.match(/sparc/)
      configure_cdom(publisher_host)
      exit
    end
    check_dhcpd_config(publisher_host)
    check_apache_config()
    # List server services
    if opt["L"]
      eval"[list_#{funct}_services()]"
      exit
    end
    # List available ISOs
    if opt["I"]
      eval"[list_#{funct}_isos()]"
      exit
    end
    # Unconfigure server services
    if opt["z"]
      eval"[unconfigure_#{funct}_server(service_name)]"
      exit
    end
    if opt["Z"] and !$os_name.match(/SunOS/)
      eval"[configure_#{funct}_server(server_type)]"
    else
      eval"[configure_#{funct}_server(client_arch,publisher_host,publisher_port,service_name,iso_file)]"
    end
    exit
  end
  # Perform maintenance related functions
  if opt["G"]
    if opt["T"]
      check_tftpd()
      restart_tftpd()
      exit
    end
    if opt["D"]
      check_dhcpd()
      restart_dhcpd()
      exit
    end
    # Handle PXE services
    if opt["P"]
      if opt["d"]
        eval"[unconfigure_#{funct}_pxe_client(client_name)]"
      end
      if opt["z"]
        eval"[unconfigure_#{funct}_pxe_boot(service_name)]"
      end
      if opt["n"]
        eval"[configure_#{funct}_pxe_boot(service_name)]"
      end
      exit
    end
    # Handle NFS services
    if opt["N"]
      if opt["n"]
        eval"[configure_#{funct}_nfs_service(service_name,publisher_host)]"
      else
        eval"[unconfigure_#{funct}_nfs_service(service_name)]"
      end
      exit
    end
    # Handle web services
    if opt["W"]
      if opt["n"]
        eval"[add_#{funct}_apache_entry(service_name)]"
      else
        eval"[remove_#{funct}_apache_entry(service_name)]"
      end
      exit
    end
    if opt["C"]
      eval"[configure_#{funct}_client_services(client_arch,publisher_host,publisher_port,service_name)]"
      exit
    end
    # Handle alternate packages (non OS install related)
    if opt["R"]
      if opt["z"]
        eval"[unconfigure_#{funct}_alt_repo(service_name)]"
      else
        eval"[configure_#{funct}_alt_repo(publisher_host,publisher_port,service_name,client_arch)]"
      end
      exit
    end
  end
  # Perform client related functions
  if opt["C"]
    # List clients
    if opt["L"]
      eval"[list_#{funct}_clients()]"
      exit
    end
    # Unconfigure client
    if opt["d"]
      eval"[unconfigure_#{funct}_client(client_name,client_mac,service_name)]"
      exit
    end
    if opt["c"]
      if !opt["K"]
        check_client_arch(client_arch,opt)
      end
      client_mac = check_client_mac(client_mac)
      if !opt["i"]
        puts "Warning:\tNo IP Address given"
        exit
      end
      check_client_ip(client_ip)
      check_dhcpd_config(publisher_host)
      eval"[configure_#{funct}_client(client_name,client_arch,client_mac,client_ip,client_model,publisher_host,service_name,image_file)]"
      if client_arch.match(/i386|x86_64/)
        if opt["2"]
          puts
          puts "This Client has been configured with serial support"
          puts
          puts "To view the installation you will need to connect to the VM via the serial port"
          puts
          puts "To boot the VM and connect to the serial port automatically boot the VM with the serial option"
          puts
          puts "If you want to boot the VM in headless mode without connecting to the serial port but want to"
          puts "connect to the serial port at a later stage you can use the following socat command:"
          puts
          puts "socat UNIX-CONNECT:/tmp/#{client_name} STDIO,raw,echo=0,escape=0x11,icanon=0"
          puts
          puts "If you wish to disconnect from this session use CTRL-Q"
          puts
        else
          puts
          puts "To connect to the serial console of this machine once booted run the following command:"
          puts
          puts "If you wish to disconnect from this session use CTRL-Q"
          puts
        end
      end
    end
  end
end
