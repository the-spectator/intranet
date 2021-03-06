namespace :delete_data do
  desc 'Delete project with name as other'
  task :delete_project_as_other => :environment do
    project = Project.where(name: 'Other').first
    project.destroy if project
  end

  desc 'Remove is_free flag'
  task :remove_is_free_flag => :environment do
    Project.all.each { |project| project.unset(:is_free) }
  end

  desc "Soft delete entry pass records prior today"
  task :soft_delete_entry_pass_old_entries => :environment do
    EntryPass.where(:date.lt => Date.today).each do |record|
      record.delete
    end
  end
end
