class Package < ApplicationRecord

  validates :name, presence: true, uniqueness: true

  has_many :versions

  def to_s
    name
  end

  def to_param
    name
  end
end
