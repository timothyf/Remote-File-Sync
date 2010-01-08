require 'rubygems'
require 'net/ssh'
require 'net/sftp'
require 'Find'


# Remote Account Info
USER_NAME = 'timothyf'
PASSWORD = '3121018'

# Paths
LOCAL_PATH = 'C:\projects\other\typo5'
REMOTE_PATH = "/home/timothyf/typo5"
REMOTE_SERVER = 'www.timothyfisher.com'

DIRS_TO_SYNC =  ['app', 'config', 'db', 'public', 'test']

IGNORE_LIST = [/CVS/, /SVN/, /ext-1/, /yui/, /tinymce/]

# Permissions used for remote files
FILE_PERM = 0644
DIR_PERM = 0755




def copy_files(sftp, dir_name)
	puts "Processing #{dir_name}..."
	local_path = "#{LOCAL_PATH}\\#{dir_name}"
	remote_path = "#{REMOTE_PATH}/#{dir_name}"	
	update_count = 0
	# Iterate through all files on local path
 	Find.find(local_path) do |file|
 		
      	local_file = File.dirname(file) + '/' + File.basename(file)
     	remote_file = remote_path + local_file.sub(local_path, '')
     	remote_dir = File.dirname(remote_file)
     	next if remote_dir =~ /CVS/   # skip CVS directories
      next if remote_dir =~ /SVN/   # skip SVN directories
     	next if remote_dir =~ /ext-1/ # skip ext directories
     	next if remote_dir =~ /yui/ # skip yui directories
     	next if remote_dir =~ /tinymce/ # skip tinymce directories
     	check_directory(remote_dir, sftp)
     	
    	next if File.stat(file).directory? # skip directories

		# Check to see if file exists
 		begin
   			rstat = sftp.stat(remote_file)
 		rescue Net::SFTP::Operations::StatusException => e
   			raise unless e.code == 2
   			# file doesn't exist on remote, so create it
   			puts "Create - " + local_file.sub(local_path, '')
   			sftp.put_file(local_file, remote_file)
   			sftp.setstat(remote_file, :permissions => FILE_PERM)
   			update_count += 1
   			next
 		end
 		if File.stat(local_file).mtime > Time.at(rstat.mtime)
 			# remote file exists, but is older than local file
   			puts "Update - " + local_file.sub(local_path, '')
   			sftp.put_file(local_file, remote_file)
   			update_count += 1
  		end
 	end
 	puts 'Number of files updated = ' + update_count.to_s
end


# Verifies existance of directory, creates it if it does not exist.
def check_directory(remote_dir, sftp)
 	begin
 		sftp.stat(remote_dir)
	rescue Net::SFTP::Operations::StatusException => e 
		raise unless e.code == 2
		# directory doesn't exist on remote, so create it
		puts "Creating directory #{remote_dir}"
		sftp.mkdir(remote_dir, :permissions => DIR_PERM)
	end  	
end

				
begin
	puts "Connecting to remote server - #{REMOTE_SERVER}"
	dirs = ['css', 'templates', 'scripts', 'lib', 'tests']
	ssh = Net::SSH.start(REMOTE_SERVER, USER_NAME, PASSWORD)
	sftp = ssh.sftp.connect
	dirs.each do |dir_name|
		copy_files(sftp, dir_name)
	end
	puts 'Closing remote server'
	sftp.close
	ssh.close
rescue Net::SSH::AuthenticationFailed
	puts "Authentication failed for user #{USER_NAME}"
rescue
	puts 'Fatal error occurred...'
end



