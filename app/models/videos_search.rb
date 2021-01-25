# == Schema Information
#
# Table name: videos_searches
#
#  video_id     :bigint           primary key
#  tsv_document :tsvector
#
class VideosSearch < ApplicationRecord
  self.primary_key = :video_id

  include PgSearch::Model

  pg_search_scope( :search, against: :tsv_document,
                    using: {
                      tsearch: {
                        dictionary: 'english',
                        tsvector_column: 'tsv_document',
                        prefix: true
                      },
                    },
                    ignoring: :accents
                  )

  def self.refresh
    Scenic.database.refresh_materialized_view(:videos_searches, concurrently: false, cascade: false)
  end

  def readonly?
    true
  end
end
