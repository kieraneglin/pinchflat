Mox.defmock(YtDlpRunnerMock, for: Pinchflat.MediaClient.Backends.BackendCommandRunner)
Application.put_env(:pinchflat, :yt_dlp_runner, YtDlpRunnerMock)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Pinchflat.Repo, :manual)
Faker.start()

setup_all do
  File.rm_rf(Application.get_env(:pinchflat, :media_directory))
  File.rm_rf(Application.get_env(:pinchflat, :metadata_directory))
end
