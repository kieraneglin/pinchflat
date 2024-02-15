Mox.defmock(YtDlpRunnerMock, for: Pinchflat.MediaClient.Backends.BackendCommandRunner)
Application.put_env(:pinchflat, :yt_dlp_runner, YtDlpRunnerMock)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Pinchflat.Repo, :manual)
Faker.start()

ExUnit.after_suite(fn _ ->
  File.rm_rf!(Application.get_env(:pinchflat, :media_directory))
  File.rm_rf!(Application.get_env(:pinchflat, :metadata_directory))

  File.mkdir_p!(Application.get_env(:pinchflat, :media_directory))
  File.mkdir_p!(Application.get_env(:pinchflat, :metadata_directory))
end)
