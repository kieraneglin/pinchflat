Mox.defmock(YtDlpRunnerMock, for: Pinchflat.Downloader.Backends.BackendCommandRunner)
Application.put_env(:pinchflat, :yt_dlp_runner, YtDlpRunnerMock)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Pinchflat.Repo, :manual)
