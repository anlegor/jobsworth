# A forum topic

class Topic < ActiveRecord::Base
  belongs_to :forum, :counter_cache => true
  belongs_to :user
  has_many :monitorships, :as => :monitorship
  has_many :monitors, :through => :monitorships, :conditions => ['monitorships.active = ?', true], :source => :user, :order => 'users.last_login_at'
  has_many :posts, :order => 'posts.created_at', :dependent => :destroy

  belongs_to :replied_by_user, :foreign_key => "replied_by", :class_name => "User"

  validates_presence_of :forum, :user, :title
  before_create :set_default_replied_at_and_sticky
  before_save   :check_for_changing_forums

  attr_accessible :title
  # to help with the create form
  attr_accessor :body

  def check_for_changing_forums
    return if new_record?
    old=Topic.find(id)
    if old.forum_id!=forum_id
      set_post_forum_id
      Forum.update_all ["posts_count = posts_count - ?", posts_count], ["id = ?", old.forum_id]
      Forum.update_all ["posts_count = posts_count + ?", posts_count], ["id = ?", forum_id]
    end
  end

  def voice_count
    posts.select("DISTINCT user_id").count
  end

  def voices
    # TODO - optimize
    posts.map { |p| p.user }.uniq
  end

  def hit!
    self.class.increment_counter :hits, id
  end

  def sticky?() sticky == 1 end

  def views() hits end

  def paged?() posts_count > 30 end

  def last_page
    (posts_count.to_f / 30.0).ceil.to_i
  end

  def editable_by?(user)
    user && (user.id == user_id || (user.admin? && forum.company_id == user.company_id) || user.admin > 2 || user.moderator_of?(forum_id))
  end

  protected
    def set_default_replied_at_and_sticky
      self.replied_at = Time.now.utc
      self.sticky   ||= 0
    end

    def set_post_forum_id
      Post.update_all ['forum_id = ?', forum_id], ['topic_id = ?', id]
    end
end


# == Schema Information
#
# Table name: topics
#
#  id           :integer(4)      not null, primary key
#  forum_id     :integer(4)
#  user_id      :integer(4)
#  title        :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#  hits         :integer(4)      default(0)
#  sticky       :integer(4)      default(0)
#  posts_count  :integer(4)      default(0)
#  replied_at   :datetime
#  locked       :boolean(1)      default(FALSE)
#  replied_by   :integer(4)
#  last_post_id :integer(4)
#
# Indexes
#
#  index_topics_on_forum_id                 (forum_id)
#  index_topics_on_sticky_and_replied_at    (forum_id,sticky,replied_at)
#  index_topics_on_forum_id_and_replied_at  (forum_id,replied_at)
#  fk_topics_user_id                        (user_id)
#

