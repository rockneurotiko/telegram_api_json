# Telegram Bot API Json

This projects scrapes the website for the [Telegram Bot API](https://core.telegram.org/bots/api) and provides a json with a more human readable interface, so API library creators can get all the methods and models without having to write them all by hand (which are a lot).

Also this helps the developers to update their libraries to the last updates easily!

## API JSON

In this repository you can find two JSON files exported:

- Minimum JSON: [https://raw.githubusercontent.com/rockneurotiko/telegram_api_json/master/exports/tg_api.json](https://raw.githubusercontent.com/rockneurotiko/telegram_api_json/master/exports/tg_api.json)
  This json is the least bytes possible, perfect to be consumed by the libraries.

- Pretty JSON: [https://raw.githubusercontent.com/rockneurotiko/telegram_api_json/master/exports/tg_api_pretty.json](https://raw.githubusercontent.com/rockneurotiko/telegram_api_json/master/exports/tg_api_pretty.json)
  This json is the same as the minimum json, but prettify, so a human can read it better :smile:


Also, you can navigate in the json with some viewer, for example: [http://jsonviewer.stack.hu/](http://jsonviewer.stack.hu/)

## Understand the JSON

The JSON have three root fields: `models`, `methods` and `generics`, each of this are a list with the defined data, let's see what can have every one of this.

### Types

Before diving into the data structures, let's define the basic types and some of the modifiers you will find.

#### Basic Types

- int : Integer
- str : String
- bool : Boolean
- float : Float
- file : InputFile, you can see the definition of this type in the [telegram documentation](https://core.telegram.org/bots/api#inputfile), but basically it can be a file ID, URL or multipart/form-data

#### Type modifiers

In the type definitions you will find basic types, telegram Model or some combination or variation, this are the variations available:

- `or` modifiers. You will see all the possible types returned in a list, for example, an integer or a string is `["int", "str"]`
- List of some type, it will have the "array" word as the first element, for example, a list of `Update` is represented as `["array", ["Update"]]`

The types can be any combination, for example, an array which can be an integer or a Update would be `["array", ["int", "Update"]]`

#### Param

In the following sections you will find references to `Param`, this is an object with the following fields:

- name: String - Name of the parameter
- description: String - Description of the parameter
- type: T - Type of the parameter, this can be any type that we've already covered or other models
- optional: Boolean - If set to true, this parameter is optional

Example of parameter, this is a parameters called `text` which is mandatory and the type is a string:

``` json
{
    "type": [
        "str"
    ],
    "optional": false,
    "name": "text",
    "description": "Text of the message to be sent"
}
```

### Models

Every model item have two root fields:

- name: String - This is the name of the model, for example `Update` or `User`
- params: [Param] - The parameters of the model

Example of a model:

``` json
{
    "name": "MessageEntity",
    "params": [
        {
            "type": [
                "str"
            ],
            "optional": false,
            "name": "type",
            "description": "Type of the entity. Can be mention (@username), hashtag, cashtag, bot_command, url, email, phone_number, bold (bold text), italic (italic text), code (monowidth string), pre (monowidth block), text_link (for clickable text URLs), text_mention (for users without usernames)"
        },
        {
            "type": [
                "int"
            ],
            "optional": false,
            "name": "offset",
            "description": "Offset in UTF-16 code units to the start of the entity"
        },
        {
            "type": [
                "int"
            ],
            "optional": false,
            "name": "length",
            "description": "Length of the entity in UTF-16 code units"
        },
        {
            "type": [
                "str"
            ],
            "optional": true,
            "name": "url",
            "description": "Optional. For “text_link” only, url that will be opened after user taps on the text"
        },
        {
            "type": [
                "User"
            ],
            "optional": true,
            "name": "user",
            "description": "Optional. For “text_mention” only, the mentioned user"
        }
    ]
}
```

### Methods

This are all the methods available in the API. This are the actions that an user can do.

This are the fields of the method object:

- name: String - Name of the method, you should use it in the path when doing the request.
- type: String - Can be `get` or `post`, this are the verb recommended to do the request, even though, you can implement it as you want.
- return: T - Type returned, check the type section
- params: [Param] - Params of the method

Example of a method:

This is the method `sendMessage`, which returns a `Message`, and have some mandatory and some optional parameters.

``` json
{
    "name": "sendMessage",
    "type": "post",
    "return": [
        "Message"
    ],
    "params": [
        {
            "type": [
                "int",
                "str"
            ],
            "optional": false,
            "name": "chat_id",
            "description": "Unique identifier for the target chat or username of the target channel (in the format @channelusername)"
        },
        {
            "type": [
                "str"
            ],
            "optional": false,
            "name": "text",
            "description": "Text of the message to be sent"
        },
        {
            "type": [
                "str"
            ],
            "optional": true,
            "name": "parse_mode",
            "description": "Send Markdown or HTML, if you want Telegram apps to show bold, italic, fixed-width text or inline URLs in your bot's message."
        },
        {
            "type": [
                "bool"
            ],
            "optional": true,
            "name": "disable_web_page_preview",
            "description": "Disables link previews for links in this message"
        },
        {
            "type": [
                "bool"
            ],
            "optional": true,
            "name": "disable_notification",
            "description": "Sends the message silently. Users will receive a notification with no sound."
        },
        {
            "type": [
                "int"
            ],
            "optional": true,
            "name": "reply_to_message_id",
            "description": "If the message is a reply, ID of the original message"
        },
        {
            "type": [
                "InlineKeyboardMarkup",
                "ReplyKeyboardMarkup",
                "ReplyKeyboardRemove",
                "ForceReply"
            ],
            "optional": true,
            "name": "reply_markup",
            "description": "Additional interface options. A JSON-serialized object for an inline keyboard, custom reply keyboard, instructions to remove reply keyboard or to force a reply from the user."
        }
    ]
}
```

### Generics

This are some types that, when specified as type, it can be any of the subtype of it.

Parameters of this objects:

- name: String - Name of the parent type, this usually are not a model, but is used as type in some parameter or return field.
- subtype: [String] - List of names of models which are subtype of this one.

Example:

``` json
{
    "subtypes": [
        "InputTextMessageContent",
        "InputLocationMessageContent",
        "InputVenueMessageContent",
        "InputContactMessageContent"
    ],
    "name": "InputMessageContent"
}
```

## Development

This project is written in Elixir and uses Floki as HTML parser to extract the Telegram API informatiion.

All contributions are welcome, if you make a PR and changes some bug or add a feature that changes the final JSON, remember to execute the script `./export.sh` to generate the new JSON files.
