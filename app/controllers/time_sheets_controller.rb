class TimeSheetsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  load_and_authorize_resource only: [:index, :projects_report]
  load_and_authorize_resource only: :individual_project_report, :class => Project
  before_action :user_exists?, only: [:create, :daily_status]

  def create
    return_value, time_sheets_data = TimeSheet.parse_timesheet_data(params) unless params['user_id'].nil?
    if return_value == true
      create_time_sheet(time_sheets_data, params)
    else
      render json: { text: '' }, status: :bad_request
    end
  end

  def index
    @from_date = params[:from_date] || Date.today.beginning_of_month.to_s
    @to_date = params[:to_date] || Date.today.to_s
    timesheets = TimeSheet.load_timesheet(@from_date.to_date, @to_date.to_date) if TimeSheet.from_date_less_than_to_date?(@from_date, @to_date)
    @timesheet_report = TimeSheet.generete_employee_timesheet_report(timesheets, @from_date.to_date, @to_date.to_date) if timesheets.present?
  end

  def users_timesheet
    redirect_to request.referrer if current_user.role.in?(['Employee', 'Intern']) && current_user.id.to_s != params[:user_id]
    
    @from_date = params[:from_date]
    @to_date = params[:to_date]
    @user = User.find(params[:user_id])
    @individual_timesheet_report, @total_work_and_leaves = TimeSheet.generate_individual_timesheet_report(@user, params) if TimeSheet.from_date_less_than_to_date?(@from_date, @to_date)
  end

  def edit
    @user = User.find_by(id: params[:id])
    @time_sheets = @user.time_sheets.where(date: params[:time_sheet_date].to_date)
    @time_sheet_date = params[:time_sheet_date]
  end

  def update
    @from_date = Date.today.beginning_of_month.to_s
    @to_date = Date.today.to_s
    @user = User.find_by(id: params['user']['id'])
    @time_sheet_date = params[:time_sheet_date]
    @time_sheets = @user.time_sheets.where(date: params[:time_sheet_date].to_date)
    return_value = TimeSheet.check_validation_while_updating_time_sheet(update_timesheet_params)
    if return_value == true
      is_updated = TimeSheet.update_time_sheet(update_timesheet_params)
      if is_updated == true
        flash[:notice] = 'Timesheet Updated Succesfully'
        redirect_to users_time_sheets_path(@user.id, from_date: @from_date, to_date: @to_date)
      else
        flash[:error] = is_updated
        render 'edit'
      end
    else
      flash[:error] = return_value
      render 'edit' 
    end
  end

  def create_time_sheet(time_sheets_data, params)
    @time_sheet.attributes = time_sheets_data
    if @time_sheet.save
      render json: { text: "*Timesheet saved successfully!*" }, status: :created
    else
      if @time_sheet.errors.messages[:from_time].present? || @time_sheet.errors.messages[:to_time].present?
        text ="\`Error :: Record already present for given time.\`"
        SlackApiService.new.post_message_to_slack(params['channel_id'], text)
      end
      render json: { text: 'Fail' }, status: :unprocessable_entity
    end
  end

  def daily_status
    @time_sheet = TimeSheet.new
    time_sheet_log = TimeSheet.parse_daily_status_command(params)
    if time_sheet_log
      render json: { text: time_sheet_log }, status: :ok
    else
      render json: { text: 'Fail' }, status: :unprocessable_entity
    end
  end

  def projects_report
    @from_date = params[:from_date] || Date.today.beginning_of_month.to_s
    @to_date = params[:to_date] || Date.today.to_s
    @projects_report = TimeSheet.load_projects_report(@from_date.to_date, @to_date.to_date) if TimeSheet.from_date_less_than_to_date?(@from_date, @to_date)
    @projects_report_in_json, @project_without_timesheet = TimeSheet.create_projects_report_in_json_format(@projects_report, @from_date.to_date, @to_date.to_date)
  end

  def individual_project_report
    @from_date = params[:from_date]
    @to_date = params[:to_date]
    @project = Project.find(params[:id])
    @individual_project_report, @project_report = TimeSheet.generate_individual_project_report(@project, params) if TimeSheet.from_date_less_than_to_date?(@from_date, @to_date)
  end

  private

  def user_exists?
    load_user
    @time_sheet = TimeSheet.new
    @user = TimeSheet.fetch_email_and_associate_to_user(params['user_id']) if @user.blank?
    unless @user
      render json: { text: 'You are not part of organization contact to admin' }, status: :unauthorized
    end
  end

  def load_user
    @user = User.where('public_profile.slack_handle' => params['user_id']).first unless params['user_id'].nil?
  end
  
  def update_timesheet_params
    params.require(:user).permit(:time_sheets_attributes => [:project_id, :date, :from_time, :to_time, :description, :id ])
  end
end