defmodule TelegramApiJson do
  require Logger

  defstruct models: [], methods: [], generics: []

  defmodule Generic do
    defstruct [:name, :subtypes]
  end

  defmodule Model do
    defstruct [:name, params: []]
  end

  defmodule Method do
    defstruct [:name, :type, :return, params: []]
  end

  defmodule Param do
    defstruct [:name, :type, :description, optional: false]
  end

  @url "https://core.telegram.org/bots/api"

  @skip []
  @generic_types ["InlineQueryResult", "InputMessageContent", "PassportElementError"]
  @zero_parameters ["getMe", "deleteWebhook", "getWebhookInfo", "getMyCommands"]

  def scrape() do
    tree() |> analyze_html(%__MODULE__{})
  end

  def scrape_and_print(pretty \\ false) do
    scrape() |> Poison.encode!(pretty: pretty) |> IO.puts()
  end

  defp tree do
    [{_, _, tree} | _] =
      get_html()
      |> Floki.parse()
      |> Floki.find("#dev_page_content")

    tree
  end

  defp analyze_html([], result), do: result

  defp analyze_html([{"h4", _, _} = elem | rest], result) do
    name = Floki.text(elem)

    cond do
      name in @skip ->
        Logger.info("Skip: #{name}")
        analyze_html(rest, result)

      name in @generic_types ->
        Logger.info("Generic: #{name}")
        generic = extract_generic(name, rest)
        result = %{result | generics: result.generics ++ [generic]}
        analyze_html(rest, result)

      isupper?(name) ->
        case length(String.split(name)) do
          1 ->
            Logger.info("Model: #{name}")
            model = extract_model(name, rest)
            result = %{result | models: result.models ++ [model]}
            analyze_html(rest, result)

          _ ->
            analyze_html(rest, result)
        end

      true ->
        Logger.info("Method: #{name}")
        method = extract_method(name, rest)
        result = %{result | methods: result.methods ++ [method]}
        analyze_html(rest, result)
    end
  end

  defp analyze_html([_ | rest], result), do: analyze_html(rest, result)

  defp extract_generic(name, tree) do
    Logger.debug("Extracting generic: #{name}")

    subtypes = tree |> find_next("ul") |> Floki.find("li") |> Enum.map(&Floki.text/1)

    %TelegramApiJson.Generic{name: name, subtypes: subtypes}
  end

  defp extract_model(name, tree) do
    Logger.debug("Extracting model: #{name}")
    params = tree |> find_next("table") |> extract_table_params()

    %TelegramApiJson.Model{name: name, params: params}
  end

  defp extract_method(name, tree) do
    type = if String.starts_with?(name, "get"), do: "get", else: "post"
    returned = tree |> find_next("p") |> Floki.text() |> extract_return_type() |> good_type()

    params =
      case name in @zero_parameters do
        true -> []
        false -> tree |> find_next("table") |> extract_table_params()
      end

    %TelegramApiJson.Method{name: name, type: type, return: returned, params: params}
  end

  defp extract_table_params(table) do
    table |> Floki.find("tr") |> Enum.drop(1) |> Enum.map(&table_row_to_param/1)
  end

  defp table_row_to_param(row) do
    {name_row, type_row, opt_row, extra_row} = extract_table_row(row)
    name = Floki.text(name_row)
    types = type_row |> Floki.text() |> parse_types()
    opt = opt_row |> Floki.text() == "Optional"
    description = extra_row |> Floki.text()

    %TelegramApiJson.Param{name: name, type: types, optional: opt, description: description}
  end

  defp extract_table_row(row) do
    case row |> Floki.find("td") do
      [name, type, extra] -> {name, type, Floki.find(extra, "em"), extra}
      [name, type, opt, extra | _] -> {name, type, opt, extra}
    end
  end

  defp parse_types(type_str) do
    type_str
    |> String.split(" or ")
    |> Stream.map(&String.trim/1)
    |> Enum.flat_map(&parse_types_elem/1)
  end

  defp parse_types_elem("Integer"), do: ["int"]
  defp parse_types_elem("String"), do: ["str"]
  defp parse_types_elem("Boolean"), do: ["bool"]
  defp parse_types_elem("True"), do: ["bool"]
  defp parse_types_elem("Float"), do: ["float"]
  defp parse_types_elem("Float number"), do: ["float"]
  defp parse_types_elem("InputFile"), do: ["file"]

  defp parse_types_elem("Array of " <> name) do
    more =
      case parse_types(name) do
        [] -> ["any"]
        other -> other
      end

    [["array", more]]
  end

  defp parse_types_elem(name) do
    cond do
      String.contains?(name, " and ") ->
        [first | rest] = String.split(name, " and ")
        [left | _] = parse_types(first)
        [right | _] = rest |> Enum.join(" and ") |> parse_types()
        [left, right]

      isupper?(name) ->
        [name]

      true ->
        []
    end
  end

  defp extract_return_type(type) do
    ts = [
      "Returns basic information about the bot in form of a ",
      "returns the edited ",
      "Returns exported invite link as ",
      "Returns the new invite link as",
      "Returns a ",
      "returns a ",
      "Returns ",
      "returns "
    ]

    cond do
      String.contains?(type, "Array of Update objects is returned") ->
        ["array", ["Update"]]

      String.contains?(type, "array of the sent Messages is returned") ->
        ["array", ["Message"]]

      String.contains?(type, "File object is returned") ->
        ["file"]

      String.contains?(type, " is returned") ->
        [type |> String.split(" is returned") |> Enum.at(0) |> String.split() |> Enum.at(-1)]

      String.contains?(type, "returns an Array of GameHighScore") ->
        ["array", ["GameHighScore"]]

      String.contains?(type, "returns an Array of ChatMember") ->
        ["array", ["ChatMember"]]

      String.contains?(type, "Returns Array of BotCommand") ->
        ["array", ["BotCommand"]]

      Enum.any?(ts, &String.contains?(type, &1)) ->
        t = Enum.find(ts, &String.contains?(type, &1))

        [String.split(type, t) |> Enum.at(1) |> String.split() |> Enum.at(0) |> String.trim(",")]

      true ->
        ["any"]
    end
  end

  defp good_type(type) when is_binary(type) do
    type = type |> String.trim(".") |> String.trim(",") |> String.trim()

    case type do
      "Int" -> "int"
      "String" -> "str"
      "True" -> "bool"
      other -> other
    end
  end

  defp good_type(type), do: type

  defp isupper?(string) do
    f = String.first(string)
    f == String.upcase(f)
  end

  defp find_next(tree, find) do
    tree |> Floki.find(find) |> Enum.at(0)
  end

  defp get_html() do
    {:ok, resp} = HTTPoison.get(@url)
    resp.body
  end
end
