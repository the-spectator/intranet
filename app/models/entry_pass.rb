class EntryPass
  include Mongoid::Document
  field :date, type: Date
  belongs_to :user

  validates :date, presence: true, uniqueness: {scope: :user_id, message:": You already have an entry pass for this date"}
  validate :validate_daily_limit

  def self.to_csv
    attributes = %w{Date Name Email}
    CSV.generate(headers: true) do |csv|
      csv << attributes
      all.each do |entry_pass|
        csv << [entry_pass.date, User.where({id: entry_pass.user_id}).first.try(:name), User.where({id: entry_pass.user_id}).first.try(:email)]
      end
    end
  end

  def validate_daily_limit
    if EntryPass.where({date: self.date}).count >= DAILY_OFFICE_ENTRY_LIMIT
      errors.add(:date, "Maximum number of employees allowed to work from office reached")
    end
  end
end

