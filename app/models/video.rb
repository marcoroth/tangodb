# == Schema Information
#
# Table name: videos
#
#  id                    :bigint           not null, primary key
#  acr_response_code     :integer
#  acrid                 :string
#  avg_rating            :integer
#  confidence_score      :string
#  description           :string
#  duration              :integer
#  hd                    :boolean          default(FALSE)
#  hidden                :boolean          default(FALSE)
#  isrc                  :string
#  length                :interval
#  performance_date      :datetime
#  performance_number    :integer
#  performance_total     :integer
#  scanned_song          :boolean          default(FALSE)
#  songmatches           :string           default([]), is an Array
#  spotify_album_name    :string
#  spotify_artist_id_2   :string
#  spotify_artist_name   :string
#  spotify_artist_name_2 :string
#  spotify_artist_name_3 :string
#  spotify_track_name    :string
#  tags                  :string
#  title                 :text
#  upload_date           :date
#  view_count            :integer
#  youtube_artist        :string
#  youtube_song          :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  channel_id            :bigint
#  event_id              :bigint
#  follower_id           :bigint
#  leader_id             :bigint
#  song_id               :bigint
#  spotify_album_id      :string
#  spotify_artist_id     :string
#  spotify_track_id      :string
#  videotype_id          :bigint
#  youtube_id            :string
#  youtube_song_id       :string
#
# Indexes
#
#  index_videos_on_channel_id    (channel_id)
#  index_videos_on_event_id      (event_id)
#  index_videos_on_follower_id   (follower_id)
#  index_videos_on_leader_id     (leader_id)
#  index_videos_on_song_id       (song_id)
#  index_videos_on_videotype_id  (videotype_id)
#

class Video < ApplicationRecord
  require 'openssl'
  require 'base64'
  require 'net/http/post/multipart'
  require 'irb'
  require 'json'

  include Filterable
  include PgSearch::Model

  validates :youtube_id, presence: true, uniqueness: true

  belongs_to :leader, required: false
  belongs_to :follower, required: false
  belongs_to :song, required: false
  belongs_to :channel, required: true
  belongs_to :search_suggestion, required: false

  scope :filter_by_orchestra,    ->(artist)          { joins(:song).where('songs.artist ILIKE ?', artist) }
  scope :filter_by_genre,     ->(genre)           { joins(:song).where('songs.genre ILIKE ?', genre) }
  scope :filter_by_leader,    ->(leader)          { joins(:leader).where('leaders.name ILIKE ?', leader) }
  scope :filter_by_follower,  ->(follower)        { joins(:follower).where('followers.name ILIKE ?', follower) }
  scope :filter_by_channel,   ->(channel)         { joins(:channel).where('channels.title ILIKE ?', channel) }
  scope :filter_by_hd,        ->                  { where(hd: true) }
  scope :paginate,            ->(page, per_page)  { offset(per_page * page).limit(per_page) }

  # Active Admin scopes
  scope :has_song,          ->   { where.not(song_id: nil) }
  scope :has_leader,        ->   { where.not(leader_id: nil) }
  scope :has_follower,      ->   { where.not(follower_id: nil) }
  scope :has_youtube_match, ->   { where.not(youtube_artist: nil) }
  scope :has_acr_match,     ->   { where(acr_response_code: 0) }
  scope :scanned_acr,       ->   { where.not(acr_response_code: nil) }
  scope :not_scanned_acr,   ->   { where(acr_response_code: nil) }

  pg_search_scope :filter_by_query, against: [:title, :description],
                                    using: {
                                      tsearch:  {
                                        dictionary: 'english', tsvector_column: "searchable"
                                      }
                                    },
                                    ignoring: :accents

  # scope :filter_by_query, -> (query) {includes(:leader, :follower, :channel, :song).filter_by_title_or_description(query).where('leaders_videos.name ILIKE :query OR followers_videos.name ILIKE :query OR songs_videos.genre ILIKE :query OR songs_videos.title ILIKE :query OR songs_videos.artist ILIKE :query OR channels_videos.title ILIKE :query', query: "%#{query}%")}




  class << self

    # def filter_by_query(search)
    #   all :conditions =>  (search ? { :tag_name => search.split} : [])
    # end

    # def filter_by_query(str)
    #   return [] if str.blank?
    #   cond_text   = str.split.map{|w| "title LIKE ? "}.join(" OR ")
    #   cond_values = str.split.map{|w| "%#{w}%"}
    #   all(:conditions =>  (str ? [cond_text, *cond_values] : []))
    # end

    # def filter_by_query(query)
    #   keywords = query.to_s.split(' ')
    #   queries = keywords.map do |search_term|
    #     where('unaccent(leaders.name) ILIKE unaccent(:q)  or
    #      unaccent(followers.name) ILIKE unaccent(:q)  or
    #      unaccent(songs.genre) ILIKE unaccent(:q)  or
    #      unaccent(songs.title) ILIKE unaccent(:q)  or
    #      unaccent(songs.artist) ILIKE unaccent(:q)  or
    #      unaccent(channels.title) ILIKE unaccent(:q)  or
    #      unaccent(videos.spotify_artist_name) ILIKE unaccent(:q)  or
    #      unaccent(videos.spotify_track_name) ILIKE unaccent(:q)  or
    #      unaccent(videos.youtube_song) ILIKE unaccent(:q)  or
    #      unaccent(youtube_artist) ILIKE unaccent(:q)  or
    #      unaccent(videos.title) ILIKE unaccent(:q)  or
    #      unaccent(videos.description) ILIKE unaccent(:q)', q: "%#{search_term}%")
    #   end
    #   statement = queries.reduce do |statement, query|
    #     statement.or(query)
    #   end
    # end

    def update_imported_video_counts
      Channel.all.each do |channel|
        channel.update(imported_videos_count: channel.videos.count)
      end
    end

    def update_import_status
      Channel.where('imported_videos_count < total_videos_count').each do |channel|
        channel.update(imported: false)
      end
    end

    def import_all_channels
      Channel.where(imported: false).order(:id).each do |channel|
        channel_id = channel.channel_id
        Video.import_channel(channel_id)
      end
    end

    def match_all_music
      Video.where(acr_response_code: nil).order(:id).each do |video|
        youtube_id = video.youtube_id
        AcrMusicMatchWorker.perform_async(youtube_id)
      end
    end

    def match_all_dancers
      Leader.all.each do |leader|
        Video.all.where(leader_id: nil).where(' unaccent(title) ILIKE unaccent(:leader_name)
                                                  OR unaccent(description) ILIKE unaccent(:leader_name)
                                                  OR unaccent(title) ILIKE unaccent(:leader_nickname)
                                                  OR unaccent(description) ILIKE unaccent(:leader_nickname)',
                                              leader_name: "%#{leader.name}%",
                                              leader_nickname: "%#{leader.nickname.blank? ? 'Do not perform match' : leader.nickname}%").each do |video|
          video.update(leader: leader)
        end
      end

      Follower.all.each do |follower|
        Video.all.where(follower_id: nil).where(' unaccent(title) ILIKE unaccent(:follower_name)
                                                    OR unaccent(description) ILIKE unaccent(:follower_name)
                                                    OR unaccent(title) ILIKE unaccent(:follower_nickname)
                                                    OR unaccent(description) ILIKE unaccent(:follower_nickname)',
                                                follower_name: "%#{follower.name}%",
                                                follower_nickname: "%#{follower.nickname.blank? ? 'Do not perform match' : follower.nickname}%").each do |video|
          video.update(follower: follower)
        end
      end
    end

    def match_all_songs
      Song.filter_by_active.sort_by_popularity.where.not(popularity: [false, nil]).each do |song|
        Video.where(song_id: nil)
             .where('unaccent(spotify_track_name) ILIKE unaccent(:song_title)
                      OR unaccent(youtube_song) ILIKE unaccent(:song_title)
                      OR unaccent(title) ILIKE unaccent(:song_title)
                      OR unaccent(description) ILIKE unaccent(:song_title)
                      OR unaccent(tags) ILIKE unaccent(:song_title)',
                    song_title: "%#{song.title}%")
             .where('spotify_artist_name ILIKE :song_artist_keyword
                      OR unaccent(spotify_artist_name_2) ILIKE unaccent(:song_artist_keyword)
                      OR unaccent(youtube_artist) ILIKE unaccent(:song_artist_keyword)
                      OR unaccent(description) ILIKE unaccent(:song_artist_keyword)
                      OR unaccent(title) ILIKE unaccent(:song_artist_keyword)
                      OR unaccent(tags) ILIKE unaccent(:song_artist_keyword)
                      OR unaccent(spotify_album_name) ILIKE unaccent(:song_artist_keyword)',
                    song_artist_keyword: "%#{song.last_name_search}%")
             .each do |video|
          video.update(song: song)
        end
      end
    end

    def calc_song_popularity
      Song.column_defaults['popularity']
      Song.column_defaults['occur_count']

      occur_num = Video.pluck(:song_id).compact!.tally
      max_value = occur_num.values.max
      popularity = occur_num.transform_values { |v| (v.to_f / max_value.to_f * 100).round }

      occur_num.each do |key, value|
        song = Song.find(key)
        song.update(occur_count: value)
      end

      popularity.each do |key, value|
        song = Song.find(key)
        song.update(popularity: value)
      end
    end

    def get_channel_video_ids(channel_id)
      `youtube-dl https://www.youtube.com/channel/#{channel_id}/videos  --get-id --skip-download`.split
    end

    def import_channel(channel_id)
      yt_channel = Yt::Channel.new id: channel_id
      yt_channel_video_count = yt_channel.video_count

      yt_channel_videos = yt_channel_video_count >= 10 ? Video.get_channel_video_ids(channel_id) : yt_channel.videos.map(&:id)

      channel = Channel.find_by(channel_id: channel_id)
      channel_videos = channel.videos.map(&:youtube_id)
      yt_channel_videos_diff = yt_channel_videos - channel_videos

      yt_channel_videos_diff.each do |youtube_id|local
        ImportVideoWorker.perform_async(youtube_id)
      end

      channel.update(
        title: yt_channel.title,
        thumbnail_url: yt_channel.thumbnail_url,
        total_videos_count: yt_channel.video_count
      )
    end

    def import_video(youtube_id)
      yt_video = Yt::Video.new id: youtube_id

      video = Video.create(youtube_id: yt_video.id,
                           title: yt_video.title,
                           description: yt_video.description,
                           upload_date: yt_video.published_at,
                           length: yt_video.length,
                           duration: yt_video.duration,
                           view_count: yt_video.view_count,
                           tags: yt_video.tags,
                           hd: yt_video.hd?,
                           channel: Channel.find_by(channel_id: yt_video.channel_id))
      channel = Channel.find(video.channel.id)
      imported_videos_count = Video.where(channel: channel).count
      imported = imported_videos_count >= channel.total_videos_count
      channel.update(imported_videos_count: imported_videos_count,
                     imported: imported)
    end

    def fetch_youtube_song(youtube_id)
      video = Video.find_by(youtube_id: youtube_id)
      yt_video = JSON.parse(YoutubeDL.download("https://www.youtube.com/watch?v=#{youtube_id}", skip_download: true)
                                  .to_json).extend Hashie::Extensions::DeepFind

      video.update(youtube_song: yt_video.deep_find('track'),
                   youtube_artist: yt_video.deep_find('artist'))
      sleep(5)
    end

    def acr_music_match(youtube_id)
      video = Video.find_by(youtube_id: youtube_id)
      clipped_audio = Video.clip_audio(youtube_id)
      acr_response_body = Video.acr_sound_match(clipped_audio)
      Video.parse_acr_response(acr_response_body, youtube_id)
    end

    # Generates audio clip from youtube_id and outputs file path
    def clip_audio(youtube_id)
      video = Video.find_by(youtube_id: youtube_id)
      audio_full = YoutubeDL.download(
        "https://www.youtube.com/watch?v=#{video.youtube_id}",
        { format: '140', output: '~/environment/data/audio/%(id)s.mp3' }
      )

      song = FFMPEG::Movie.new(audio_full.filename.to_s)

      time_1 = audio_full.duration / 2
      time_2 = time_1 + 20

      output_file_path = audio_full.filename.gsub(/.mp3/, "_#{time_1}_#{time_2}.mp3")

      song_transcoded = song.transcode(output_file_path,
                                       { custom: %W[-ss #{time_1} -to #{time_2}] })
      output_file_path
    end

    # Parse response spotify, youtube, and isrc information from ACR_sound_match
    def parse_acr_response(acr_response, youtube_id)
      youtube_video = Video.find_by(youtube_id: youtube_id)
      video = JSON.parse(acr_response).extend Hashie::Extensions::DeepFind

      if video['status']['code'] == 0 && video.deep_find('spotify').present?

        spotify_album_id = video.deep_find('spotify')['album']['id'] if video.deep_find('spotify')['album'].present?
        if video.deep_find('spotify')['album']['id'].present?
          spotify_album_name = RSpotify::Album.find(spotify_album_id).name
        end

        if video.deep_find('spotify')['artists'][0].present?
          spotify_artist_id = video.deep_find('spotify')['artists'][0]['id']
        end

        if video.deep_find('spotify')['artists'][0].present?
          spotify_artist_name = RSpotify::Artist.find(spotify_artist_id).name
        end

        if video.deep_find('spotify')['artists'][1].present?
          spotify_artist_id_2 = video.deep_find('spotify')['artists'][1]['id']
        end

        if video.deep_find('spotify')['artists'][2].present?
          spotify_artist_id_3 = video.deep_find('spotify')['artists'][2]['id']
        end

        if video.deep_find('spotify')['artists'][1].present?
          spotify_artist_name_2 = RSpotify::Artist.find(spotify_artist_id_2).name
        end

        if video.deep_find('spotify')['track']['id'].present?
          spotify_track_id = video.deep_find('spotify')['track']['id']
        end

        if video.deep_find('spotify')['track']['id'].present?
          spotify_track_name = RSpotify::Track.find(spotify_track_id).name
        end

        youtube_song_id = video.deep_find('youtube')['vid'] if video.deep_find('youtube').present?
        isrc = video.deep_find('external_ids')['isrc'] if video.deep_find('external_ids')['isrc'].present?

        youtube_video.update(
          spotify_album_id: spotify_album_id,
          spotify_album_name: spotify_album_name,
          spotify_artist_id: spotify_artist_id,
          spotify_artist_name: spotify_artist_name,
          spotify_artist_id_2: spotify_artist_id_2,
          spotify_artist_name_2: spotify_artist_name_2,
          spotify_track_id: spotify_track_id,
          spotify_track_name: spotify_track_name,
          youtube_song_id: youtube_song_id,
          isrc: isrc,
          acr_response_code: video['status']['code']
        )

      elsif video['status']['code'] == 0 && video.deep_find('external_ids')['isrc'].present?
        youtube_video.update(
          acr_response_code: video['status']['code'],
          isrc: video.deep_find('external_ids')['isrc']
        )

      else
        youtube_video.update(
          acr_response_code: video['status']['code']
        )
      end
    rescue Module
    rescue RestClient::Exceptions::OpenTimeout
    rescue FFMPEG::Error
    rescue Errno::ENOENT
    rescue StandardError
    end

    # accepts file path and submits a http request to ACR Cloud API
    def acr_sound_match(file_path)
      requrl = 'http://identify-eu-west-1.acrcloud.com/v1/identify'
      access_key = ENV['ACRCLOUD_ACCESS_KEY']
      access_secret = ENV['ACRCLOUD_SECRET_KEY']

      http_method = 'POST'
      http_uri = '/v1/identify'
      data_type = 'audio'
      signature_version = '1'
      timestamp = Time.now.utc.to_i.to_s

      string_to_sign = http_method + "\n" + http_uri + "\n" + access_key + "\n" + data_type + "\n" + signature_version + "\n" + timestamp

      digest = OpenSSL::Digest.new('sha1')
      signature = Base64.encode64(OpenSSL::HMAC.digest(digest, access_secret, string_to_sign))

      sample_bytes = File.size(file_path)

      url = URI.parse(requrl)
      File.open(file_path) do |file|
        req = Net::HTTP::Post::Multipart.new url.path,
                                             'sample' => UploadIO.new(file, 'audio/mp3', file_path),
                                             'access_key' => access_key,
                                             'data_type' => data_type,
                                             'signature_version' => signature_version,
                                             'signature' => signature,
                                             'sample_bytes' => sample_bytes,
                                             'timestamp' => timestamp
        res = Net::HTTP.start(url.host, url.port) do |http|
          http.request(req)
        end
        body = res.body.force_encoding('utf-8')
        body
      end
    end

    # To fetch specific snippet from video, run this in the console:

    # Video.youtube_trim("5HfJ_n3wvLw","00:02:40.00", "00:02:55.00")
    def youtube_trim(youtube_id, time_1, time_2)
      youtube_video = YoutubeDL.download(
        "https://www.youtube.com/watch?v=#{youtube_id}",
        { format: 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best',
          output: '~/downloads/youtube/%(title)s-%(id)s.%(ext)s' }
      )
      video = FFMPEG::Movie.new(youtube_video.filename.to_s)
      timestamp = time_1.to_s.split(':')
      timestamp_2 = time_2.to_s.split(':')
      output_file_path = youtube_video.filename.gsub(/.mp4/,
                                                     "_trimmed_#{timestamp[1]}_#{timestamp[2]}_to_#{timestamp_2[1]}_#{timestamp_2[2]}.mp4")
      video_transcoded = video.transcode(output_file_path, custom: %W[-ss #{time_1} -to #{time_2}])
    end
  end
end
