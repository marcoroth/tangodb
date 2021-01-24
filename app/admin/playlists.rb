ActiveAdmin.register Playlist do
  permit_params :slug, :title, :description, :channel_title, :channel_id, :video_count

  config.sort_order = 'id_asc'
  config.per_page = [100, 500, 1000]

  index do
    selectable_column
    id_column
    column :slug
    column :title
    column :channel_title
    column :channel_id
    column :video_count
    column :imported
    actions
  end

  form do |f|
    f.inputs do
      f.input :slug, label: 'Channel ID'
    end
    f.actions
  end
end
