defmodule Pinchflat.TestingHelperMethods do
  @moduledoc false

  use ExUnit.CaseTemplate

  def now do
    DateTime.utc_now()
  end

  def now_plus(offset, unit) when unit in [:minute, :minutes] do
    DateTime.add(now(), offset, :minute)
  end

  def assert_changed(checker_fun, action_fn) do
    before_res = checker_fun.()
    action_fn.()
    after_res = checker_fun.()

    assert before_res != after_res
  end

  def assert_changed([from: from, to: to], checker_fun, action_fn) do
    before_res = checker_fun.()
    action_fn.()
    after_res = checker_fun.()

    assert before_res == from
    assert after_res == to
  end
end
