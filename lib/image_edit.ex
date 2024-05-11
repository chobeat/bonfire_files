defmodule Bonfire.Files.Image.Edit do
  import Untangle
  alias Bonfire.Files
  alias Bonfire.Common.Extend
  alias Bonfire.Common.Types

  def image(filename, max_width, max_height) do
    ext = Files.file_extension_only(filename)

    max_size = "#{max_width}x#{max_height}"

    cond do
      ext not in ["jpg", "jpeg", "png", "gif", "webp"] ->
        # to avoid error `svgload: operation is blocked`
        nil

      System.find_executable("vipsthumbnail") ->
        {:vipsthumbnail,
         fn input, output ->
           "#{input} --size #{max_size} --linear --export-profile srgb -o #{output}[strip]"
           # |> info()
         end, ext}

      System.find_executable("convert") ->
        {:convert, "-strip -thumbnail #{max_size}> -limit area 10MB -limit disk 50MB"}

      true ->
        fn _version, %{path: filename} = waffle_file ->
          image_resize_thumbnail(filename, max_size, waffle_file)
        end
    end
  end

  def thumbnail(filename, max_size) do
    ext = Files.file_extension_only(filename)

    cond do
      ext not in ["jpg", "jpeg", "png", "gif", "webp"] ->
        # avoid error `svgload: operation is blocked`
        nil

      System.find_executable("vipsthumbnail") ->
        {:vipsthumbnail,
         fn input, output ->
           "#{input} --smartcrop attention -s #{max_size} --linear --export-profile srgb -o #{output}[strip]"
           # |> info()
         end, ext}

      System.find_executable("convert") ->
        {:convert,
         "-strip -thumbnail #{max_size}x#{max_size}^ -gravity center -crop #{max_size}x#{max_size}+0+0 -limit area 10MB -limit disk 20MB"}

      true ->
        fn _version, %{path: filename} = waffle_file ->
          image_resize_thumbnail(filename, max_size, waffle_file)
        end
    end
  end

  def thumbnail_video(filename, scrub, max_size) do
    ext = Files.file_extension_only(filename)

    cond do
      # ext not in ["mp4", "ogv", "mpg", "mpeg", "webm"] ->
      #   nil

      Extend.module_exists?(Image.Video) ->
        {fn _version, %{path: filename} = waffle_file ->
           video_image_thumbnail(filename, scrub, max_size, waffle_file)
           |> IO.inspect(label: "thumbnail_video_ran")
         end, fn _version, _file -> "jpg" end}

      # System.find_executable("convert") ->
      #   {:convert,
      #    "[#{scrub*30}] -strip -thumbnail #{max_size}x#{max_size}^ -gravity center -crop #{max_size}x#{max_size}+0+0 -limit area 10MB -limit disk 20MB"}

      true ->
        nil
    end
    |> IO.inspect(label: "thumbnail_video")
  end

  def thumbnail_pdf(_filename) do
    # TODO: configurable
    max_size = 1024

    cond do
      System.find_executable("pdftocairo") ->
        {:pdftocairo,
         fn original_path, new_path ->
           " -png -singlefile -scale-to #{max_size} #{original_path} #{String.slice(new_path, 0..-5)}"
         end, :png}

      System.find_executable("vips") ->
        {:vips,
         fn original_path, new_path ->
           " copy #{original_path}[n=1,page=1,dpi=144] #{String.slice(new_path, 0..-5)}"
         end, :png}

      true ->
        nil
    end
  catch
    :exit, e ->
      error(e)
      nil

    e ->
      error(e)
      nil
  end

  def banner(filename, max_width, max_height) do
    ext = Bonfire.Files.file_extension_only(filename)

    max_size = "#{max_width}x#{max_height}"

    cond do
      ext not in ["jpg", "jpeg", "png", "gif", "webp"] ->
        # avoid error `svgload: operation is blocked`
        nil

      System.find_executable("vipsthumbnail") ->
        {:vipsthumbnail,
         fn input, output ->
           "#{input} --smartcrop attention --size #{max_size} --linear --export-profile srgb -o #{output}[strip]"
           # |> info()
         end, ext}

      System.find_executable("convert") ->
        {:convert, "-strip -thumbnail #{max_size}> -limit area 10MB -limit disk 50MB"}

      true ->
        fn _version, %{path: filename} = waffle_file ->
          image_resize_thumbnail(filename, max_size, waffle_file)
        end
    end
  end

  def video_image_thumbnail(filename, scrub_sec, max_size, waffle_file \\ %Waffle.File{}) do
    filename
    |> IO.inspect(label: "thumbnail_video_run")

    with true <- Extend.module_exists?(Image.Video),
         {:ok, %{fps: fps, frame_count: frame_count} = video} <-
           Image.Video.open(filename)
           #  video <- Image.Video.stream!(frame: scrub_frames..scrub_frames//2) # TODO?
           |> IO.inspect(label: "thumbnail_video_open"),
         {:ok, image} <-
           Image.Video.image_from_video(video, frame: frame_to_scrub(scrub_sec, fps, frame_count))
           |> IO.inspect(label: "thumbnail_video_image") do
      # image_resize_thumbnail(image, max_size, waffle_file) # FIXME: results in `Unknown image type ".mp4"`
      image_save_temp_file(image, waffle_file, "#{Waffle.File.generate_temporary_path()}.jpg")
    else
      e ->
        IO.warn(inspect(e))
        error(e, "Could not generate a video thumbnail")
        nil
    end
  catch
    :exit, e ->
      error(e)
      nil

    e ->
      error(e)
      nil
  end

  def frame_to_scrub(scrub_sec, fps, frame_count) do
    scrub_frames = scrub_sec * fps

    cond do
      scrub_frames < frame_count -> scrub_frames
      # frame_count > 35 -> frame_count-30
      true -> Types.maybe_to_integer(frame_count / 4)
    end
    |> IO.inspect(label: "thumbnail_video_frame_to_scrub")
  end

  def image_resize_thumbnail(image, max_size, waffle_file \\ %Waffle.File{}) do
    # TODO: return a Stream instead of creating a temp file: https://hexdocs.pm/image/Image.html#stream!/2
    with true <- Extend.module_exists?(Image),
         {:ok, image} <- Image.thumbnail(image, max_size, crop: :attention) do
      image_save_temp_file(image, waffle_file)
    else
      e ->
        error(e, "Could not create or save thumbnail")
        nil
    end
  catch
    :exit, e ->
      error(e)
      nil

    e ->
      error(e)
      nil
  end

  def image_save_temp_file(image, waffle_file \\ %Waffle.File{}, tmp_path \\ nil) do
    tmp_path = tmp_path || Waffle.File.generate_temporary_path(waffle_file)

    with {:ok, _} <- Image.write(image, tmp_path) |> IO.inspect(label: "thumbnail_video_write") do
      {:ok, %Waffle.File{waffle_file | path: tmp_path, is_tempfile?: true}}
    else
      e ->
        error(e, "Could not save image")
        nil
    end
  end

  @doc """
  Returns the dominant color of an image (given as path, binary, or stream) as HEX value.

  `bins` is an integer number of color frequency bins the image is divided into. The default is 10.
  """
  def dominant_color(file_path_or_binary_or_stream, bins \\ 15, fallback \\ "#FFF8E7") do
    with true <- Extend.module_exists?(Image),
         {:ok, img} <- Image.open(file_path_or_binary_or_stream),
         {:ok, color} <-
           Image.dominant_color(img, [{:bins, bins}])
           |> debug()
           |> Image.Color.rgb_to_hex()
           |> debug() do
      color
    else
      e ->
        error(e, "Could not calculate image color")
        debug(File.cwd())
        fallback
    end
  rescue
    e in MatchError ->
      error(e, "Could not calculate image color")
      fallback
  end

  # catch an issue when trying to blur gifs
  def blur(path, final_path) when not is_nil(path) do
    format = "jpg"

    cond do
      System.find_executable("convert") ->
        Mogrify.open(path)
        # NOTE: since we're resizing an already resized thumnail, don't worry about cropping, stripping, etc
        |> Mogrify.resize("10%")
        |> Mogrify.custom("colors", "8")
        |> Mogrify.custom("depth", "8")
        |> Mogrify.custom("blur", "2x2")
        |> Mogrify.quality("20")
        |> Mogrify.format(format)
        # |> IO.inspect
        |> Mogrify.save(path: final_path)
        |> Map.get(:path)

      System.find_executable("vips") ->
        with {_, 0} <-
               System.cmd("vips", ["resize", path, "#{final_path}", "0.10"]) do
          final_path
        end

      true ->
        nil
    end
  rescue
    e in File.CopyError ->
      error(e)
      nil
  end
end
