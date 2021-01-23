# frozen_string_literal: true

class MediaManagesController < ApplicationController
  include MediaManagesHelper
  include YoutubeUtils
  before_action :check_signed_in
  before_action :media_manage, only: [:edit, :show, :update, :destroy, :restore, :fetch]
  before_action :check_can_restore, only: [:restore]

  def index
    @media_manages = current_user.media_manage.list
  end

  def new
    # 新規登録formは用意せず、modelを作ってeditに飛ばす
    media_manage = current_user.media_manage.create(title: '新規')
    media_manage.save
    redirect_to edit_media_manage_path(media_manage)
  end

  def edit; end

  def show
    @time_spans = @media_manage.time_spans
    @media_time_image = MediaTimeImage.new
  end

  def update
    if @media_manage.update(media_manage_params)
      flash[:success] = '動画情報を更新しました'
      try_update_youtube
      redirect_to @media_manage
    else
      render 'edit'
    end
  end

  def destroy
    flash[:success] = '動画情報を削除しました'
    @media_manage.destroy
    redirect_to media_manages_url
  end

  def restore
    MediaTimeSpan.transaction do
      curr_seq_id = @media_manage.curr_seq_id
      prev_seq_id = @media_manage.curr_seq_id - 1
      @media_manage.update(curr_seq_id: prev_seq_id)
      @media_manage.media_time_span.where(seq_id: curr_seq_id).destroy_all
    end

    flash[:success] = '元に戻しました'
    redirect_to @media_manage
  end

  def fetch
    try_update_youtube
    redirect_to @media_manage
  end

  private

  def check_signed_in
    return if user_signed_in?

    redirect_to new_user_session_url
  end

  def check_can_restore
    return if @media_manage.can_restore

    flash[:error] = '戻すバージョンがありません'
    redirect_to @media_manage
  end

  def media_manage_params
    params.require(:media_manage).permit(:title, :thumbnail, :media_url, :media_sec)
  end

  def media_manage
    @media_manage = current_user.media_manage.find_by(id: params[:id])

    return unless @media_manage.nil?

    flash[:error] = 'このURLは存在しません'
    redirect_to root_url
  end

  # youtubeのmediaであれば、youtubeから情報を取得する
  def try_update_youtube
    return unless @media_manage.youtube_video?

    info = fetch_youtube_video_info(@media_manage.youtube_video_id)
    logger.info("youtube info[#{info}]")

    update_youtube(info)
  rescue YoutubeFetchError => e
    logger.error("youtube fetch error. #{e}")
    flash[:warn] = 'youtubeからの取得に失敗しました。'
  end

  # youtubeから取得した情報でUPDATEする
  def update_youtube(info)
    if @media_manage.update(info)
      flash[:info] = 'youtubeからの取得に成功しました。'
    else
      flash[:warn] = 'youtube情報の保存に失敗しました。'
    end
  end
end
