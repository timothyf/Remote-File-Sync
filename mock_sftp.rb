require 'rubygems'
require 'net/ssh'
require 'net/sftp'
require 'net/sftp/operations/abstract'


class MockSftp
	
	attr_accessor :files_put
	attr_accessor :dirs_created
	attr_accessor :setstat_files
	
	def initialize
		@files_put = []
		@setstat_files = []
		@dirs_created = []
	end
	
	
	def reset
		initialize
	end
	
	
	# Throws a StatusException if the file or directory passed as a parameter does not exist.
	# This implementation simulates three existing files or directories.
	def stat(dir)
		#puts 'MockSftp.stat called with '+dir
		if dir != '/remote/test/test_files/test_old_file.txt' &&
       dir != '/remote/test' && 
       dir != '/remote/test/test_files' &&
		   dir != '/remote/test/test_files/test_file.txt' &&
		   dir != '/remote/test/test_files/level1'
			raise Net::SFTP::Operations::StatusException.new(2, '', '')	
		end
		return RStat.new
	end
	
	
	def setstat(filename, permissions)
		#puts 'MockSftp.setstat called'
		@setstat_files << filename
	end
	
	
	def put_file(local_file, remote_file)
		#puts 'MockSftp.put_file called with '+local_file+' and '+remote_file
		@files_put << remote_file
	end
	
	
	def mkdir(remote_dir, permissions)
		#puts 'MockSftp.mkdir called'
		@dirs_created << remote_dir
	end
	
	class RStat		
		attr_accessor :use_old
		
		def initialize
			@use_old = false
		end
		
		def mtime
			if @use_old
				return Time.local(2000, "jan", 1, 20, 15, 1)
			else 
				return Time.new
			end
		end
	end
	
end
