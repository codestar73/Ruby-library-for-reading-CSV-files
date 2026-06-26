# frozen_string_literal: true

module CsvPipeline
  module RuleInvoker
    module_function

    def call_field_rule(callable, value, record)
      if callable.is_a?(Proc)
        invoke_proc(callable, value, record)
      else
        callable.call(value)
      end
    end

    def invoke_proc(proc, value, record)
      case proc.arity
      when 1 then proc.call(value)
      when 2 then proc.call(value, record)
      when -1, -2 then proc.call(value)
      else proc.call(value, record)
      end
    end
  end
end
