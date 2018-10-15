defmodule TelegramApiJsonTest do
  use ExUnit.Case
  doctest TelegramApiJson

  test "greets the world" do
    assert TelegramApiJson.hello() == :world
  end
end
