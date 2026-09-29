module Api
  module V1
    class VideosController < BaseController
      def create
        video = current_user.videos.new(video_params)

        if video.save
          render json: { id: video.id, status: video.status }, status: :created
        else
          render json: { errors: video.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def show
        video = Video.find(params[:id])
        render json: video_response(video)
      end

      def index
        videos = Video.public_video.order(created_at: :desc)
        render json: videos.map { |v| video_response(v) }
      end

      def update
        video = current_user.videos.find_by(id: params[:id])

        if video.update(video_params)
            render json: video_response(video)
        else
            render json: { errors: video.errors.full_messages }, status: :unprocessable_content
        end
        
        rescue ActiveRecord::RecordNotFound
        render json: { error: "Video not found or not yours" }, status: :not_found
      end

      private

      def video_params
        params.require(:video).permit(:title, :description, :visibility, :raw_video)
      end

      def video_response(video)
        {
          id: video.id,
          title: video.title,
          description: video.description,
          status: video.status,
          duration_seconds: video.duration_seconds,
          manifest_url: video.manifest_url,
          view_count: video.view_count
        }
      end
    end
  end
end