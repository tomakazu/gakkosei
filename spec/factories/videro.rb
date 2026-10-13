FactoryBot.define do
  factory :video do
    user
    title { "Intro to Rails" }
    visibility { :public_video }

    trait :private do
      visibility { :private_video }
    end

    trait :unlisted do
      visibility { :unlisted }
    end

    # Attaches a fake file BEFORE the first save, so the
    # after_commit transcoding callback sees it.
    trait :with_file do
      after(:build) do |video|
        video.raw_video.attach(
          io: StringIO.new("not a real video"),
          filename: "sample.mp4",
          content_type: "video/mp4"
        )
      end
    end
  end
end