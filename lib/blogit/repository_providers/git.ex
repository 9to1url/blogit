defmodule Blogit.RepositoryProviders.Git do
  require Logger

  @behaviour Blogit.RepositoryProvider

  @repository_url Application.get_env(:blogit, :repository_url)
  @local_path @repository_url
              |> String.split("/")
              |> List.last
              |> String.trim_trailing(".git")
  @posts_folder Application.get_env(:blogit, :posts_folder, ".")

  def repository do
    case Git.clone(@repository_url) do
      {:ok, repo} -> repo
      {:error, %Git.Error{code: 128}} -> Git.new(@local_path)
    end
  end

  def updated_repository do
    repo = repository()
    case Git.pull(repo) do
      {:ok, msg} -> Logger.info("Pulling from git repository #{msg}")
      {_, error} ->
        Logger.error(
          "Error while pulling from git repository #{inspect(error)}"
        )
    end

    repo
  end

  def fetch(repo) do
    case Git.fetch(repo) do
      {:error, _} -> {:no_updates}
      {:ok, ""} -> {:no_updates}
      {:ok, _} ->
        updates =
          Git.diff!(repo, ["--name-only", "HEAD", "origin/master"])
          |> String.split("\n", trim: true) |> Enum.map(&String.trim/1)
        Git.pull!(repo)

        {:updates, updates}
    end
  end

  def local_path, do: @local_path
  def local_files, do: File.ls!(Path.join(@local_path, @posts_folder))
  def file_in?(file), do: File.exists?(Path.join(@local_path, file))

  def file_author(repository, file_name) do
    first_in_log(repository, ["--reverse", "--format=%an", file_name])
  end

  def file_created_at(repository, file_name) do
    first_in_log(repository, ["--reverse", "--format=%ci", file_name])
  end

  def file_updated_at(repository, file_name) do
    log(repository, ["-1", "--format=%ci", file_name]) |> String.trim
  end

  def read_file!(file_path, folder \\ "") do
    file = local_path()
           |> Path.join(folder) |> Path.join(file_path)

    File.read!(file)
  end

  def read_file(file_path, folder \\ "") do
    local_path() |> Path.join(folder) |> Path.join(file_path) |> File.read
  end

  def read_meta_file(file_path, folder \\ "") do
    meta_file_path = file_path |> String.replace_suffix(".md", ".yml")
    meta_path = local_path()
                |> Path.join(folder)
                |> Path.join("meta")
                |> Path.join(meta_file_path)

    File.read(meta_path)
  end

  defp log(repository, args), do: Git.log!(repository, args)

  defp first_in_log(repository, args) do
    log(repository, args) |> String.split("\n") |> List.first |> String.trim
  end
end
