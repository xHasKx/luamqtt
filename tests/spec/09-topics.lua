local mqtt = require "mqtt"

describe("topics", function()

	describe("publish (plain)", function()
		it("allows proper topics", function()
			local ok, err
			ok, err = mqtt.validate_publish_topic("hello/world")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_publish_topic("hello/world/")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_publish_topic("/hello/world")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_publish_topic("/")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_publish_topic("//////")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_publish_topic("/")
			assert.is_nil(err)
			assert.is.truthy(ok)

		end)

		it("returns the topic passed in on success", function()
			local ok = mqtt.validate_publish_topic("hello/world")
			assert.are.equal("hello/world", ok)
		end)

		it("must be a string", function()
			local ok, err = mqtt.validate_publish_topic(true)
			assert.is_false(ok)
			assert.is_string(err)
		end)

		it("minimum length 1", function()
			local ok, err = mqtt.validate_publish_topic("")
			assert.is_false(ok)
			assert.is_string(err)
		end)

		it("wildcard '#' is not allowed", function()
			local ok, err = mqtt.validate_publish_topic("hello/world/#")
			assert.is_false(ok)
			assert.is_string(err)
		end)

		it("wildcard '+' is not allowed", function()
			local ok, err = mqtt.validate_publish_topic("hello/+/world")
			assert.is_false(ok)
			assert.is_string(err)
		end)

	end)



	describe("subscribe (wildcarded)", function()

		it("allows proper topics", function()
			local ok, err
			ok, err = mqtt.validate_subscribe_topic("hello/world")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_subscribe_topic("hello/world/")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_subscribe_topic("/hello/world")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_subscribe_topic("/")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_subscribe_topic("//////")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_subscribe_topic("#")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_subscribe_topic("/#")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_subscribe_topic("+")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_subscribe_topic("+/hello/#")
			assert.is_nil(err)
			assert.is.truthy(ok)

			ok, err = mqtt.validate_subscribe_topic("+/+/+/+/+")
			assert.is_nil(err)
			assert.is.truthy(ok)
		end)

		it("returns the topic passed in on success", function()
			local ok = mqtt.validate_subscribe_topic("hello/world")
			assert.are.equal("hello/world", ok)
		end)

		it("must be a string", function()
			local ok, err = mqtt.validate_subscribe_topic(true)
			assert.is_false(ok)
			assert.is_string(err)
		end)

		it("minimum length 1", function()
			local ok, err = mqtt.validate_subscribe_topic("")
			assert.is_false(ok)
			assert.is_string(err)
		end)

		it("wildcard '#' is only allowed as last segment", function()
			local ok, err = mqtt.validate_subscribe_topic("hello/#/world")
			assert.is_false(ok)
			assert.is_string(err)
		end)

		it("wildcard '+' is only allowed as full segment", function()
			local ok, err = mqtt.validate_subscribe_topic("hello/+there/world")
			assert.is_false(ok)
			assert.is_string(err)
		end)

	end)



	describe("pattern compiler & matcher", function()

		it("basic parsing works", function()
			local opts = {
				topic = "+/+",
				pattern = nil,
				keys = { "hello", "world"}
			}
			local res, err = mqtt.topic_match("hello/world", opts)
			assert.is_nil(err)
			assert.same(res, {
				"hello", "world",
				hello = "hello",
				world = "world",
			})
			-- compiled pattern is now added
			assert.not_nil(opts.pattern)
		end)

		it("incoming topic is required", function()
			local opts = {
				topic = "+/+",
				pattern = nil,
				keys = { "hello", "world"}
			}
			local ok, err = mqtt.topic_match(nil, opts)
			assert.is_false(ok)
			assert.is_string(err)
		end)

		it("wildcard topic or pattern is required", function()
			local opts = {
				topic = nil,
				pattern = nil,
				keys = { "hello", "world"}
			}
			local ok, err = mqtt.topic_match("hello/world", opts)
			assert.is_false(ok)
			assert.is_string(err)
		end)

		it("pattern must match", function()
			local opts = {
				topic = "+/+/+", -- one too many
				pattern = nil,
				keys = { "hello", "world"}
			}
			local ok, err = mqtt.topic_match("hello/world", opts)
			assert.is_false(ok)
			assert.is_string(err)
		end)

		it("pattern '+' works", function()
			local opts = {
				topic = "+",
				pattern = nil,
				keys = { "hello" }
			}
			-- matches topic
			local res, err = mqtt.topic_match("hello", opts)
			assert.is_nil(err)
			assert.same(res, {
				"hello",
				hello = "hello",
			})
		end)

		it("wildcard '+' matches empty segments", function()
			local opts = {
				topic = "+/+/+",
				pattern = nil,
				keys = { "hello", "there", "world"}
			}
			local res, err = mqtt.topic_match("//", opts)
			assert.is_nil(err)
			assert.same(res, {
				"", "", "",
				hello = "",
				there = "",
				world = "",
			})
		end)

		it("pattern '#' matches all segments", function()
			local opts = {
				topic = "#",
				pattern = nil,
				keys = nil,
			}
			local res, var = mqtt.topic_match("hello/there/world", opts)
			assert.same(res, {
				"hello/there/world"
			})
			assert.same(var, {
				"hello",
				"there",
				"world",
			})
		end)

		it("pattern '/#' skips first segment", function()
			local opts = {
				topic = "/#",
				pattern = nil,
				keys = nil,
			}
			local res, var = mqtt.topic_match("/hello/world", opts)
			assert.same(res, {
				"hello/world"
			})
			assert.same(var, {
				"hello",
				"world",
			})
		end)

		it("combined wildcards '+/+/#'", function()
			local opts = {
				topic = "+/+/#",
				pattern = nil,
				keys = nil,
			}
			local res, var = mqtt.topic_match("hello/there/my/world", opts)
			assert.same(res, {
				"hello",
				"there",
				"my/world"
			})
			assert.same(var, {
				"my",
				"world",
			})
		end)

		it("trailing '/' in topic with '#'", function()
			local opts = {
				topic = "+/+/#",
				pattern = nil,
				keys = nil,
			}
			local res, var = mqtt.topic_match("hello/there/world/", opts)
			assert.same(res, {
				"hello",
				"there",
				"world/"
			})
			assert.same(var, {
				"world",
				"",
			})
		end)


	end)

end)
