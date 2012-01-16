class Album < ActiveRecord::Base
  extend FriendlyId
  friendly_id :name, :use => :slugged

  scope :ordered, order('albums.name ASC').joins(:photos).group('photos.album_id').having('count(photos.album_id) > 0') # only galleries that have photos

  has_many :photos

  validates :name, :presence => true
  validates :path, :presence => true

  def is_new?
    unless modified.nil?
      Date.parse(modified).to_datetime.in_time_zone('UTC') > 1.month.ago
    else
      false
    end
  end

  def cache_photos
    CacherQeue.create(:album_id => self.id) if self.photo.not_cached.count > 0
  end

  def build_photos
    BuilderQeue.create(:album_path => self.path)
  end
end
