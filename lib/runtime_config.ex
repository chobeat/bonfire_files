defmodule Bonfire.Files.RuntimeConfig do
  @behaviour Bonfire.Common.ConfigModule
  def config_module, do: true

  def config do
    import Config

    config :furlex, Furlex.Oembed,
      extra_providers: [
        %{
          "provider_name" => "Crossref",
          "provider_url" => "doi.org",
          "fetch_function" => {Bonfire.Files.DOI, :fetch},
          "endpoints" => [
            %{
              "schemes" =>
                Bonfire.Files.DOI.pub_id_and_uri_matchers()
                |> Map.values()
              #      "url" => "https://api.crossref.org/works/",
              #      "append_url" => true 
            }
          ]
        }
      ]

    # where do you want to store uploaded files? supports local storage, s3-compatible services, and more, see https://hexdocs.pm/waffle/Waffle.html#module-setup-a-storage-provider
    # an example s3 compatible service: https://www.scaleway.com/en/pricing/?tags=storage
    # The default is local storage.

    if System.get_env("UPLOADS_S3_BUCKET") &&
         System.get_env("UPLOADS_S3_ACCESS_KEY_ID") &&
         System.get_env("UPLOADS_S3_SECRET_ACCESS_KEY") do
      # Use s3-compatible cloud storage

      bucket = System.get_env("UPLOADS_S3_BUCKET")

      # specify the bucket's host and region (defaults to Scaleway Paris), see:
      # https://www.scaleway.com/en/docs/storage/object/quickstart/
      # https://docs.aws.amazon.com/general/latest/gr/rande.html
      region = System.get_env("UPLOADS_S3_REGION", "fr-par")
      host = System.get_env("UPLOADS_S3_HOST", "s3.#{region}.scw.cloud")
      scheme = System.get_env("UPLOADS_S3_SCHEME", "https://")
      port = System.get_env("UPLOADS_S3_PORT", "443")

      if config_env() not in [:test, :dev] || System.get_env("USE_S3") do
        IO.puts("Note: uploads will be stored in s3: #{bucket} at #{host}")
        config :bonfire_files, :storage, :s3
      end

      config :entrepot, Entrepot.Storages.S3, bucket: bucket
      # config :entrepot, Entrepot.Storages.Disk, root_dir: "data/uploads"

      config :waffle,
        storage: Waffle.Storage.S3,
        bucket: bucket,
        asset_host: System.get_env("UPLOADS_S3_URL", "#{scheme}#{bucket}.#{host}/")

      config :ex_aws,
        json_codec: Jason,
        access_key_id: System.get_env("UPLOADS_S3_ACCESS_KEY_ID"),
        secret_access_key: System.get_env("UPLOADS_S3_SECRET_ACCESS_KEY"),
        region: region,
        s3: [
          scheme: scheme,
          host: host,
          region: region,
          port: port
        ]
    else
      config :bonfire_files, :storage, :local

      config :waffle,
        storage: Waffle.Storage.Local,
        # or {:system, "ASSET_HOST"}
        asset_host: "/"
    end

    # TODO: how can we make this configurable from ENV vars?

    image_media = %{
      "image/png" => "png",
      "image/jpeg" => ["jpg", "jpeg"],
      "image/gif" => "gif",
      "image/svg+xml" => "svg",
      "image/webp" => ["webp"]
      # "image/tiff"=> "tiff"
    }

    video_media = %{
      "video/mp4" => ["mp4", "mp4v", "mpg4"],
      "video/mpeg" => ["mpeg", "m1v", "m2v", "mpa", "mpe", "mpg"],
      "video/ogg" => ["ogg", "ogv"],
      "video/x-matroska" => ["mkv"],
      "application/x-matroska" => ["mkv"],
      "video/webm" => ["webm"],
      "video/3gpp" => ["3gp"],
      "video/3gpp2" => ["3g2"],
      "video/x-msvideo" => ["avi"],
      "video/quicktime" => ["mov", "qt"]
    }

    all_allowed_media =
      Map.merge(image_media, video_media)
      |> Map.merge(%{
        "text/plain" => ["txt"],
        "text/markdown" => ["md"],
        # doc
        "text/csv" => ["csv"],
        "text/tab-separated-values" => ["tsv"],
        "application/pdf" => ["pdf"],
        "application/rtf" => "rtf",
        # "application/msword"=> ["doc", "dot"],
        # "application/vnd.openxmlformats-officedocument.wordprocessingml.document"=> ["docx"],
        # "application/vnd.ms-excel"=> ["xls"],
        # "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"=> ["xlsx"],
        # "application/vnd.oasis.opendocument.presentation"=> ["odp"],
        # "application/vnd.oasis.opendocument.spreadsheet"=> ["ods"],
        # "application/vnd.oasis.opendocument.text"=> ["odt"],
        "application/epub+zip" => ["epub"],
        # archives
        # "application/x-tar"=> ["tar"],
        # "application/x-bzip"=> ["bzip"],
        # "application/x-bzip2"=> ["bzip2"],
        # "application/gzip"=> ["gz", "gzip"],
        # "application/zip"=> ["zip"],
        # "application/rar"=> ["rar"],
        # "application/vnd.rar"=> ["rar"],
        # "application/x-7z-compressed"=> ["7z"],
        # audio
        "audio/mpeg" => ["mpa", "mp2"],
        "audio/m4a" => ["m4a"],
        "audio/mp4" => ["m4a", "mp4"],
        "audio/x-m4a" => ["m4a"],
        "audio/aac" => ["aac"],
        "audio/mp3" => ["mp3"],
        "audio/ogg" => ["ogg", "oga"],
        "audio/wav" => ["wav"],
        "audio/webm" => ["webm"],
        "audio/opus" => ["opus"],
        "audio/flac" => ["flac"]
      })

    all_allowed_media_types = all_allowed_media |> Map.keys()

    all_allowed_media_extensions =
      all_allowed_media |> Map.values() |> List.flatten() |> Enum.uniq() |> Enum.map(&".#{&1}")

    image_media_types = image_media |> Map.keys()

    image_media_extensions =
      image_media |> Map.values() |> List.flatten() |> Enum.uniq() |> Enum.map(&".#{&1}")

    video_media_types = video_media |> Map.keys()

    video_media_extensions =
      video_media |> Map.values() |> List.flatten() |> Enum.uniq() |> Enum.map(&".#{&1}")

    config :bonfire_files,
      image_media_types: image_media_types,
      image_media_extensions: image_media_extensions,
      # TODO: put sizes in env
      max_user_images_file_size: 8,
      max_user_video_file_size: 20,
      max_docs_file_size: 6,
      all_allowed_media_types: all_allowed_media_types,
      all_allowed_media_extensions: all_allowed_media_extensions

    config :bonfire_files, Bonfire.Files.DocumentUploader,
      allowed_media_types: all_allowed_media_types,
      allowed_media_extensions: all_allowed_media_extensions

    config :bonfire_files, Bonfire.Files.VideoUploader,
      allowed_media_types: video_media_types,
      allowed_media_extensions: video_media_extensions

    config :bonfire_files, Bonfire.Files.IconUploader,
      allowed_media_types: image_media_types,
      allowed_media_extensions: image_media_extensions

    config :bonfire_files, Bonfire.Files.ImageUploader,
      allowed_media_types: image_media_types,
      allowed_media_extensions: image_media_extensions,
      max_width: System.get_env("IMAGE_MAX_W", "700"),
      max_height: System.get_env("IMAGE_MAX_H", "700")

    # NOTE: this is avoid LV uploads failing with `invalid accept filter provided to allow_upload. Expected a file extension with a known MIME type.`
    # NOTE2: seems this needs to be compile-time
    # config :mime, :types, Map.merge(%{
    #   "application/json" => ["json"],
    #   "application/activity+json" => ["activity+json"],
    #   "application/ld+json" => ["ld+json"],
    #   "application/jrd+json" => ["jrd+json"]
    # }, all_allowed_media)
  end
end
