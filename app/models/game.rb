class Game < ActiveRecord::Base
  require 'net/http'

  serialize :data

  has_many :ratings
  has_many :users, through: :ratings

  belongs_to :user

  validates :steam_appid, uniqueness: true

  before_create :get_data

  def rating
    ratings_array = ratings.visible

    if ratings_array.size == 0
      return false
    end

    total = 0

    ratings_array.each do |rating|
      total += rating.total
    end

    return total / ratings_array.size
  end

  # Stats

  def ranking
    Rating.ranking(rating)
  end

  def get_stat_string stat
    value = get_stat stat

    return "N/A" if value.nan?

    Rating.send(stat.to_s.pluralize.to_sym).to_a[value][0]
  end

  def get_stat stat
    average_array ratings.visible.map {|rating| rating[stat]}
  end

  def get_rounded_stat stat
    get_stat(stat).round
  end

  def average_array array
    array.inject{ |sum, el| sum + el }.to_f / array.size
  end

  # Static Data

  def name
    data[data.keys[0]]["data"]["name"] if data
  end

  def description
    desc = data[data.keys[0]]["data"]["detailed_description"] if data
    return desc.html_safe if desc
    return nil
  end

  def dlc
    data[data.keys[0]]["data"]["dlc"] if data
  end

  def min_requirements
    req = data[data.keys[0]]["data"]["pc_requirements"]["minimum"] if data
    return req.html_safe if req
    return nil
  end

  def recommended_requirements
    req = data[data.keys[0]]["data"]["pc_requirements"]["recommended"] if data
    return req.html_safe if req
    return nil
  end

  def developers
    data[data.keys[0]]["data"]["developers"] if data
  end

  def publishers
    data[data.keys[0]]["data"]["publishers"] if data
  end

  def header_image
    data[data.keys[0]]["data"]["header_image"] if data
  end

  def website
    data[data.keys[0]]["data"]["website"] if data
  end

  def launch_game_link
    "steam://run/#{id}"
  end

  def rated_by_user? user
    return false unless user

    rating = Rating.find_by(user_id: user.id, game_id: self.id)

    return true if rating
    return false
  end

  private

    def get_data
      url = "http://store.steampowered.com/api/appdetails/?appids=#{steam_appid}"
      resp = Net::HTTP.get_response(URI.parse(url))
      data = JSON.parse(resp.body)

      self.data = data

      if data[data.keys[0]]["data"].blank? || resp.code == "403"
        self.errors.add :Game, "does not exist"
        return false
      end
    end

end
