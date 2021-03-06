namespace :update_data do
  desc 'Update type of project and billing frequency column'
  task :update_project_fields => :environment do
    projects = Project.where(is_free: true).update_all(type_of_project: 'Free', billing_frequency: 'NA')
    projects = Project.where(is_free: false).update_all(type_of_project: 'T&M', billing_frequency: 'Monthly')
  end

  desc 'Update Leave Type column'
  task :update_leave_type_field => :environment do
    LeaveApplication.update_all(leave_type: LeaveApplication::LEAVE)
  end
end
