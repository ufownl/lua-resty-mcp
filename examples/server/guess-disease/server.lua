local _M = {
  _NAME = "guess-disease.server",
  _VERSION = "1.0"
}

local server_instruction = "You are the control terminal of the disease guessing game. You MUST reply with the result of the tool call in the same language as the user query."
local assistant_prompt = "You are a helpful assistant who is proficient in medical knowledge."
local function patient_prompt(self)
  return string.format("You are participating in a disease guessing game. You play the role of a patient in this game. The disease you suffer from may have the following symptoms:\n\n%s\n\nPlease note that the character you are playing is very lacking in medical knowledge and cannot accurately and fluently describe your condition to the doctor.", self.symptoms)
end

local function game_state(self, mcp, server)
  return server:replace_tools({
    mcp.tool("inquiry", function(args, ctx)
      table.insert(self.history, {
        role = "user",
        content = {
          type = "text",
          text = args.content
        }
      })
      local res, err = ctx.session:create_message(self.history, 8192, {
        systemPrompt = patient_prompt(self),
        includeContext = "none",
        temperature = 0.7
      }, 60)
      if not res then
        return nil, err
      end
      if not res.content.text then
        return nil, "invalid response type: "..res.content.type
      end
      table.insert(self.history, {role = res.role, content = res.content})
      return "Patient: "..res.content.text
    end, {
      description = "Ask the patient about his/her specific conditions.",
      input_schema = {
        type = "object",
        properties = {
          content = {
            type = "string",
            description = "The content of inquiry. Please put the full inquiry content into this argument in English."
          }
        },
        required = {"content"}
      }
    }),
    mcp.tool("diagnose", function(args, ctx)
      local res, err = ctx.session:create_message({
        {
          role = "user",
          content = {
            type = "text",
            text = string.format("My name is %s and I am participating in a round of the disease guessing game. My guess is %s and the answer is %s. Please judge whether I guessed correctly.", self.name, args.disease, self.answer)
          }
        }
      }, 4096, {
        systemPrompt = assistant_prompt,
        includeContext = "none",
        temperature = 0.2
      }, 60)
      if not res then
        return nil, err
      end
      if not res.content.text then
        return nil, "invalid response type: "..res.content.type
      end
      ctx.session:replace_tools({self.start_game})
      return "Host: "..res.content.text
    end, {
      description = "Make a diagnosis for the patient.",
      input_schema = {
        type = "object",
        properties = {
          disease = {
            type = "string",
            description = "The diagnosed disease. Please put the name of this disease in English."
          }
        },
        required = {"disease"}
      }
    })
  })
end

local _MT = {
  __index = {
    _NAME = _M._NAME
  }
}

function _MT.__index.initialize(self, mcp, server)
  self.start_game = mcp.tool("start_game", function(args, ctx)
    local res, err = ctx.session:elicit("Please provide your name.", {
      type = "object",
      properties = {
        name = {
          type = "string",
          description = "Your name in this round of the game.",
          minLength = 2,
          maxLength = 64
        }
      },
      required = {"name"}
    }, 180)
    if not res then
      return nil, err
    end
    if res.action ~= "accept" then
      return nil, "The name was not provided. Please start the game again."
    end
    self.name = res.content.name
    local res, err = ctx.session:create_message({
      {
        role = "user",
        content = {
          type = "text",
          text = string.format("My name is %s and the current date and time is %s. I am participating in a round of the disease guessing game. Please give me a list of real-life disease names (one disease name per line), I will select one of them as the answer to this round. Note that you should reply with only the names of these diseases, without description, explanation, or other content.", self.name, os.date("%c", ngx.now()))
        }
      }
    }, 4096, {
      systemPrompt = assistant_prompt,
      includeContext = "none",
      temperature = 1.2
    }, 60)
    if not res then
      return nil, err
    end
    if not res.content.text then
      return nil, "invalid response type: "..res.content.type
    end
    local candidates = {}
    local j = 0
    repeat
      local i = string.find(res.content.text, "%w", j + 1)
      if not i then
        break
      end
      j = string.find(res.content.text, "\n", i + 1, true)
      table.insert(candidates, string.sub(res.content.text, i, j))
    until j == nil
    if #candidates < 1 then
      return nil, "invalid response"
    end
    self.answer = candidates[math.random(1, #candidates)]
    local res, err = ctx.session:create_message({
      {
        role = "user",
        content = {
          type = "text",
          text = string.format("Please list all possible symptoms of %s (one symptom per line). Note that you should reply with only a list of the disease's symptoms, without any explanation, description, or other content, especially without the name or keywords of the disease.", self.answer)
        }
      }
    }, 4096, {
      systemPrompt = assistant_prompt,
      includeContext = "none",
      temperature = 0.4
    }, 60)
    if not res then
      return nil, err
    end
    if not res.content.text then
      return nil, "invalid response type: "..res.content.type
    end
    self.symptoms = res.content.text
    self.history = {
      {
        role = "user",
        content = {
          type = "text",
          text = string.format("The current date and time is %s. You have walked into the doctor %s's office.", os.date("%c", ngx.now()), self.name)
        }
      }
    }
    local res, err = ctx.session:create_message(self.history, 8192, {
      systemPrompt = patient_prompt(self),
      includeContext = "none",
      temperature = 0.7
    }, 60)
    if not res then
      return nil, err
    end
    if not res.content.text then
      return nil, "invalid response type: "..res.content.type
    end
    table.insert(self.history, {role = res.role, content = res.content})
    game_state(self, mcp, ctx.session)
    return "Patient: "..res.content.text
  end, {description = "Start a round of the disease guessing game."})
  local ok, err = server:register(self.start_game)
  return ok and server_instruction, err
end

function _M.new()
  return setmetatable({}, _MT)
end

return _M
