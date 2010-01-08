require 'rubygems'
require 'net/ssh'
require 'net/sftp'
require 'Find'
require 'yaml'


# Update remote files that are new or have changed on the local server.
# Directories that are empty on the local server will NOT get created on
# on the remote server.
class RemoteFileSync	
	
  attr_reader :user_name
  attr_reader :password
  attr_reader :remote_server
  attr_reader :file_perm
  attr_reader :dir_perm
	attr_accessor :local_path
	attr_accessor :remote_path
	attr_accessor :dirs_to_sync
	attr_accessor :ignore_list
	
	def initialize(config_file)
		read_config(config_file)
	end
	
	
	# Connect to SFTP server and call peform_sync to perform local to
	# remote file synchronization.
	def process
		begin
			puts "Connecting to remote server - #{@remote_server}"
			Net::SSH.start(@remote_server, @user_name, @password) do |session|
				session.sftp.connect do |sftp|
					perform_sync sftp
				end
			end
			puts "Disconnected from remote server - #{@remote_server}"
		rescue Net::SSH::AuthenticationFailed
			puts "Authentication failed for user #{@user_name}"
		rescue
			puts 'Fatal error occurred!!'			
		end
	end
	
	
	# Step through an array of directories, performing local to remote synchronization
	# on each of them.
	def perform_sync(sftp)		
		@dirs_to_sync.each do |dir_name|
			copy_files(sftp, dir_name)
		end
	end
	
	
	# Read configuration from remote_file_sync.yml file to create
	# instance configuration variables.
	def read_config(config_file)
   
    settings = YAML::load_file(config_file)
    
    # Remote Server Info
    @user_name = settings['remote_host']['username']
    @password = settings['remote_host']['password']
    @remote_server = settings['remote_host']['server']
    @remote_path = settings['remote_host']['path']
    @file_perm = settings['remote_host']['file_perm']
    @dir_perm = settings['remote_host']['dir_perm']
    
    # Paths
    @local_path = settings['properties']['local_path']
    @dirs_to_sync = settings['properties']['dirs_to_sync']
    @ignore_list = settings['properties']['ignore_list']
	end
	
	
	# Update remote files that are new or have changed on the local server.
	# Directories that are empty on the local server will NOT get created on
	# on the remote server.
	def copy_files(sftp, dir_name)
		puts "Processing #{dir_name}..."
		local_path = "#{@local_path}/#{dir_name}"
		remote_path = "#{@remote_path}/#{dir_name}"
		update_count = 0
		# Iterate through all files on local path
	 	Find.find(local_path) do |file|	
	      local_file = File.dirname(file) + '/' + File.basename(file)
	     	remote_file = remote_path + local_file.sub(local_path, '')
	     	remote_dir = File.dirname(remote_file)
        
        next if check_ignore_list(remote_dir)

	     	check_directory(remote_dir, sftp)
	     	
	    	next if File.stat(file).directory? # skip directories
	 		
	 		if !(rstat = confirm_or_create_file(sftp, remote_file, local_file, local_path))
	 			update_count += 1
	 			next  # file was created, move onto the next file
 			end			
 			update_count += update_out_of_date_file(local_file, local_path, sftp, remote_file, rstat)
	 	end
	 	puts 'Number of files updated = ' + update_count.to_s
	end
	
  
  def check_ignore_list(remote_dir)
    @ignore_list.each do |ignore|
      if remote_dir =~ ignore   # skip directory
        return true
      end
    end 
    return false
  end
	
  
	# Check to see if a file exists on the remote server, if it does not
	# exist, then create it.
	def confirm_or_create_file(sftp, remote_file, local_file, local_path)
		# Check to see if file exists
 		begin
   			return sftp.stat(remote_file)
 		rescue Net::SFTP::Operations::StatusException => e
   			raise unless e.code == 2
   			# file doesn't exist on remote, so create it
   			puts "Create - " + local_file.sub(local_path, '')
   			sftp.put_file(local_file, remote_file)
   			sftp.setstat(remote_file, :permissions => @file_perm)
   			return nil
 		end
	end
	
	
	# If a remote file has a timestamp which is older than the timestamp of the
	# same local file, then replace it with the local file.
	def update_out_of_date_file(local_file, local_path, sftp, remote_file, rstat)
 		if File.stat(local_file).mtime > Time.at(rstat.mtime)
 			# remote file exists, but is older than local file
   			sftp.put_file(local_file, remote_file)
   			return 1
  		else
  			return 0
  		end
	end


	# Verifies existance of directory, creates it if it does not exist.
	def check_directory(remote_dir, sftp)
	 	begin
	 		sftp.stat(remote_dir)
		rescue Net::SFTP::Operations::StatusException => e 
			raise unless e.code == 2
			# directory doesn't exist on remote, so create it
			puts "Creating directory #{remote_dir}"
			sftp.mkdir(remote_dir, :permissions => @dir_perm)
		end  	
	end
	
end
