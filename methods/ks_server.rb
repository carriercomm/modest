
# Server code for Kickstart

# Unconfigure alternate packages

def unconfigure_alt_pkg_ks(service_name)
  return
end

# Configure alternate packages

def configure_alt_pkg_ks(service_name)
  rpm_list=build_ks_alt_rpm_list(service_name)
  alt_dir=$repo_base_dir+"/"+service_name+"/alt"
  check_dir_exists(alt_dir)
  rpm_list.each do |rpm_url|
    rpm_file=File.basename(rpm_url)
    rpm_file=alt_dir+"/"+rpm_file
    if !File.exists?(rpm_file)
      wget_file(rpm_url,rpm_file)
    end
  end
  return
end

# Unconfigure Linux repo

def unconfigure_ks_repo(service_name)
  remove_apache_alias(service_name)
  repo_version_dir=$repo_base_dir+"/"+service_name
  destroy_zfs_fs(repo_version_dir)
  return
end

# Copy Linux ISO contents to

def configure_ks_repo(iso_file,repo_version_dir)
  check_zfs_fs_exists(repo_version_dir)
  check_dir=repo_version_dir+"/isolinux"
  if $verbose_mode == 1
    puts "Checking:\tDirectory "+check_dir+" exits"
  end
  if !File.directory?(check_dir)
    mount_iso(iso_file)
    copy_iso(iso_file,repo_version_dir)
    umount_iso()
  end
  return
end

# Unconfigure Kickstart server

def unconfigure_ks_server(service_name)
  unconfigure_ks_repo(service_name)
end

# Configure PXE boot

def configure_ks_pxe_boot(service_name)
  pxe_boot_dir=$tftp_dir+"/"+service_name
  test_dir=pxe_boot_dir+"/usr"
  if !File.directory?(test_dir)
    if service_name.match(/centos/)
      rpm_dir=$repo_base_dir+"/"+service_name+"/CentOS"
    else
      rpm_dir=$repo_base_dir+"/"+service_name+"/Packages"
    end
    if File.directory?(rpm_dir)
      message="Locating syslinux package"
      command="ls #{rpm_dir} |grep 'syslinux-[0-9]'"
      output=execute_command(message,command)
      rpm_file=output.chomp
      rpm_file=rpm_dir+"/"+rpm_file
      check_dir_exists(pxe_boot_dir)
      message="Copying:\tPXE boot files from "+rpm_file+" to "+pxe_boot_dir
      command="cd #{pxe_boot_dir} ; rpm2cpio #{rpm_file} | cpio -iud"
      output=execute_command(message,command)
    else
      puts "Warning:\tSource directory "+rpm_dir+" does not exist"
      exit
    end
  end
  pxe_image_dir=pxe_boot_dir+"/images"
  if !File.directory?(pxe_image_dir)
    iso_image_dir=$repo_base_dir+"/"+service_name+"/images"
    message="Copying:\tPXE boot images from "+iso_image_dir+" to "+pxe_image_dir
    command="cp -r #{iso_image_dir} #{pxe_boot_dir}"
    output=execute_command(message,command)
  end
  pxe_cfg_dir=$tftp_dir+"/pxelinux.cfg"
  check_dir_exists(pxe_cfg_dir)
  return
end

# Unconfigure PXE boot

def unconfigure_ks_pxe_boot(service_name)
  return
end

# Configure Kickstart server

def configure_ks_server(client_arch,publisher_host,publisher_port,service_name,iso_file)
  if service_name.match(/[A-z]/)
    if service_name.downcase.match(/centos/)
      search_string="CentOS"
    end
    if service_name.downcase.match(/redhat/)
      search_string="rhel"
    end
  else
    search_string="[CentOS|rhel]"
  end
  if iso_file.match(/[A-z]/)
    if File.exists?(iso_file)
      iso_list[0]=iso_file
    else
      puts "Warning:\tISO file "+is_file+" does not exist"
    end
  else
    iso_list=check_iso_base_dir(search_string)
  end
  iso_list.each do |iso_file|
    iso_file=iso_file.chomp
    iso_linux_info=File.basename(iso_file)
    iso_linux_info=iso_linux_info.split(/-/)
    linux_distro=iso_linux_info[0]
    linux_distro=linux_distro.downcase
    if linux_distro.match(/centos/)
      iso_linux_version=iso_linux_info[1]
    else
      iso_linux_version=iso_linux_info[2]
    end
    iso_linux_version=iso_linux_version.gsub(/\./,"_")
    release_dir=linux_distro+"_"+iso_linux_version
    repo_version_dir=$repo_base_dir+"/"+release_dir
    add_apache_alias(release_dir)
    configure_ks_repo(iso_file,repo_version_dir)
    configure_ks_pxe_boot(release_dir)
  end
  return
end

# List kickstart services

def list_ks_services()
  puts "Kickstart services:"
  service_list=Dir.entries($repo_base_dir)
  service_list.each do |service_name|
    if service_name.match(/centos|redhat/)
      puts service_name
    end
  end
  return
end
