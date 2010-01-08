require 'test/unit'
require 'remote_file_sync'
require 'mock_sftp'


class RemoteFileSyncTest < Test::Unit::TestCase
	
	FILE_NOT_ON_REMOTE 			= "not_on_remote.txt"
	FILE_CURRENT_ON_REMOTE 		= "test_file.txt"
	FILE_OUT_OF_DATE_ON_REMOTE 	= "test_old_file.txt"
	
	def setup   
    settings = YAML::load_file('test_config.yml')   
    @remote_path = settings['remote_host']['path']
    @local_path = settings['properties']['local_path']
		@sync = RemoteFileSync.new('test_config.yml')
		@sftp = MockSftp.new
  end

  def test_read_config
    @sync = RemoteFileSync.new('test_config.yml')
    assert @sync.user_name == 'test_user'
    assert @sync.password == 'test_pass'
    assert @sync.remote_server == 'www.timothyfisher.com'
    assert @sync.remote_path == '/remote/test'
    assert @sync.file_perm == 0644
    assert @sync.dir_perm == 0755
    assert @sync.local_path == '.'
    assert @sync.dirs_to_sync.class == Array
    assert @sync.dirs_to_sync[0] == 'app'
    assert @sync.dirs_to_sync[4] == 'test'
    assert @sync.ignore_list.class == Array
    assert @sync.ignore_list.size == 5
    assert @sync.ignore_list[0].class == Regexp
    assert @sync.ignore_list[0] == /CVS/
    assert @sync.ignore_list[1] == /SVN/
    assert @sync.ignore_list[4] == /tinymce/
  end
	
  def test_ignore_list
    @sync.copy_files(@sftp, 'test_files')
    assert @sftp.files_put.size == 2
    assert @sftp.files_put.include?("#{@remote_path}/test_files/#{FILE_NOT_ON_REMOTE}")
    assert @sftp.files_put.include?("#{@remote_path}/test_files/level1/#{FILE_NOT_ON_REMOTE}")
    assert @sftp.dirs_created.size == 0
    #assert @sftp.dirs_created.include?("#{@remote_path}/test_files/level1")  
  end
  
	def test_perform_sync
		@sync.dirs_to_sync = ['test_files']
		@sync.perform_sync(@sftp)
		assert @sftp.files_put.size == 2
		assert @sftp.files_put.include?("#{@remote_path}/test_files/#{FILE_NOT_ON_REMOTE}")
		assert @sftp.files_put.include?("#{@remote_path}/test_files/level1/#{FILE_NOT_ON_REMOTE}")
		assert @sftp.dirs_created.size == 0
		#assert @sftp.dirs_created.include?("#{@remote_path}/test_files/level1")
	end
		
	def test_copy_files
		@sync.copy_files(@sftp, 'test_files')
		assert @sftp.files_put.size == 2
		assert @sftp.files_put.include?("#{@remote_path}/test_files/#{FILE_NOT_ON_REMOTE}")
		assert @sftp.files_put.include?("#{@remote_path}/test_files/level1/#{FILE_NOT_ON_REMOTE}")
		assert @sftp.dirs_created.size == 0
		#assert @sftp.dirs_created.include?("#{@remote_path}/test_files/level1")
	end
	
	
	def test_confirm_or_create_file
		# file does not exist on remote so should be created
		@sync.confirm_or_create_file(@sftp, 
									 "#{@remote_path}/test_files/#{FILE_NOT_ON_REMOTE}", 
									 "#{@local_path}\\test_files\\#{FILE_NOT_ON_REMOTE}", 
									 @local_path)
		assert @sftp.files_put.include?("#{@remote_path}/test_files/#{FILE_NOT_ON_REMOTE}")
		assert @sftp.setstat_files.include?("#{@remote_path}/test_files/#{FILE_NOT_ON_REMOTE}")
		
		# file exists on remote so should not be created
		@sync.confirm_or_create_file(@sftp, 
									 "#{@remote_path}/test_files/#{FILE_CURRENT_ON_REMOTE}", 
									 "#{@local_path}\test_files\#{FILE_CURRENT_ON_REMOTE}", 
									 @local_path)
		assert !@sftp.files_put.include?(FILE_CURRENT_ON_REMOTE)
	end
	
	
	def test_update_out_of_date_file
		# should not update file
		@sync.update_out_of_date_file("#{@local_path}\\test_files\\#{FILE_CURRENT_ON_REMOTE}", 
									                "#{@local_path}/test_files", 
                                  @sftp, 
									                "#{@remote_path}/#{FILE_CURRENT_ON_REMOTE}", 
									                MockSftp::RStat.new)
		assert !@sftp.files_put.include?(FILE_CURRENT_ON_REMOTE)
		
		# should update file
		rstat = MockSftp::RStat.new
		rstat.use_old = true
		@sync.update_out_of_date_file("#{@local_path}\\test_files\\#{FILE_OUT_OF_DATE_ON_REMOTE}", 
									  "{#@local_path}/test_files", 
									  @sftp, 
									  "#{@remote_path}/test_files/#{FILE_OUT_OF_DATE_ON_REMOTE}", 
									  rstat)
		assert @sftp.files_put.include?("#{@remote_path}/test_files/#{FILE_OUT_OF_DATE_ON_REMOTE}")
	end
	
	
	def test_check_directory
		# should create non-existing directory
		@sync.check_directory("#{@remote_path}/test_files/not_existing", @sftp)
		assert @sftp.dirs_created.size == 1
		assert @sftp.dirs_created.include?("#{@remote_path}/test_files/not_existing")
		
		# should not create existing directory
		@sftp.reset
		@sync.check_directory("#{@remote_path}/test_files/level1", @sftp)
		assert @sftp.dirs_created.size == 0
	end
	
end

