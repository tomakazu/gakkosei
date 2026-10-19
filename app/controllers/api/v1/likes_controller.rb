module Api
  module V1
    class LikesController < BaseController
      before_action :set_video

      # POST /api/v1/videos/:video_id/like
      def create
        current_user.likes.find_or_create_by!(video: @video)
        render json: like_state
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        # Two requests at the same moment: the other one already liked it. Still a success.
        render json: like_state
      end

      # DELETE /api/v1/videos/:video_id/like
      def destroy
        current_user.likes.find_by(video: @video)&.destroy
        render json: like_state
      end

      private

      def set_video
        @video = Video.find(params[:video_id])

        if @video.private_video? && @video.user_id != current_user.id
          render json: { error: "Video not found" }, status: :not_found
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Video not found" }, status: :not_found
      end

      def like_state
        {
          liked: current_user.likes.exists?(video: @video),
          likes_count: @video.reload.likes_count
        }
      end
    end
  end
end