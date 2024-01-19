defmodule Pinchflat.Repo do
  use Ecto.Repo,
    otp_app: :pinchflat,
    adapter: Ecto.Adapters.Postgres
end
