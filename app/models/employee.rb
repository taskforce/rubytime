require 'logger'

class Employee < User
  validates_present :role
  
  has n, :activities
  
  before :destroy do
    throw :halt if activities.count > 0
  end
  
  def send_timesheet_nagger_for(date)
    m = UserMailer.new(:user => self, :day_without_activities => date)
    m.dispatch_and_deliver(:timesheet_nagger, :to => email, :from => Rubytime::CONFIG[:mail_from], :subject => "RubyTime timesheet nagger!")
  end
  
  def self.without_activities_on(date)
    all.reject { |employee| employee.has_activities_on?(date) }
  end
  
  def self.send_timesheet_naggers_for(date, logger = Logger.new(nil))
    Employee.without_activities_on(date).each do |employee|
      logger.info "Sending timesheet nagger email to #{employee.name}."
      employee.send_timesheet_nagger_for(date)
    end
  end
  
  def self.send_timesheet_naggers_for__if_enabled(date, logger = Logger.new(nil))
    if Setting.enable_notifications
      send_timesheet_naggers_for(date, logger)
    else
      logger.error "Won't send timesheet naggers: notifications are disabled."
    end
  end
  
  def self.send_timesheet_reporter_for(date, email, logger = Logger.new(nil))
    logger.info "Sending timesheet report email to #{email}."
    m = UserMailer.new(:employees_without_activities => Employee.without_activities_on(date), :day_without_activities => date)
    m.dispatch_and_deliver(:timesheet_reporter, :to => email, :from => Rubytime::CONFIG[:mail_from], :subject => "RubyTime timesheet report")
  end
  
  def self.send_timesheet_reporter_for__if_enabled(date, email, logger = Logger.new(nil))
    if Setting.enable_notifications
      send_timesheet_reporter_for(date, email, logger)
    else
      logger.error "Won't send timesheet report: notifications are disabled."
    end
  end
  
  def send_timesheet_summary_for(dates_range)
    m = UserMailer.new(:user => self,
      :dates_range => dates_range,
      :activities_by_dates_and_projects => activities_by_dates_and_projects(dates_range) )
    m.dispatch_and_deliver(:timesheet_summary, :to => email, :from => Rubytime::CONFIG[:mail_from], :subject => "RubyTime timesheet summary")
  end
  
  def activities_by_dates_and_projects(dates_range)
    activities_grouped_by_days = activities(:date => dates_range).group_by{|a| a.date}
    activities_grouped_by_days.default = []
    
    dates_range.to_a.map do |date|
      [ date, activities_grouped_by_days[date].group_by{|a|a.project}.map.sort_by{|project,activity|project.name} ]
    end
  end
  
  def self.send_timesheet_summary_for(dates_range, logger = Logger.new(nil))
    all.each do |employee|
      logger.info "Sending timesheet summary email to #{employee.name}."
      employee.send_timesheet_summary_for(dates_range)
    end
  end
  
  def self.send_timesheet_summary_for__if_enabled(dates_range, logger = Logger.new(nil))
    if Setting.enable_notifications
      send_timesheet_summary_for(dates_range, logger)
    else
      logger.error "Won't send timesheet summary: notifications are disabled."
    end
  end
end
