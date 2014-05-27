module ParamsValidator
  module Filter
    extend ActiveSupport::Inflector

    def self.sanitize_params(params, definition)
      errors = {}
      definition.each do |field, validation_definition|
        errors = validate_field(field, params, validation_definition, errors)

        validation_definition.reject {|k,v| reserved_keys.include?(k) }.each do |nested_field, nested_validation_definition|
          sanitize_params(params[field.to_s], { nested_field => nested_validation_definition })
        end
      end
      raise InvalidParamsException.new(errors) unless errors.empty?
      params
    end

    private

    def self.reserved_keys
      @reserved_keys ||= [:_default, :_whitelist, :_with, :_param_key].to_set
    end

    def self.validate_field(field, params, validation_definition, errors)
      param_key = validation_definition[:_param_key]
      validators = validation_definition[:_with]
      return errors unless validators
      validators.each do |validator_name|
        camelized_validator_name = self.camelize(validator_name)
        begin
          validator = ParamsValidator::Validator.const_get(camelized_validator_name)
          validator = validator.new(validation_definition)
          value = params.is_a?(Hash) ? (param_key.nil? ? params[field.to_s] : params[param_key][field.to_s]) : nil
          unless validator.valid?(value)
            if validator.respond_to?(:default?) && validator.default?
              if param_key.nil?
                params[field] = validator.default
              else
                params[param_key][field] = validator.default
              end
            else
              errors[field] = validator.error_message
            end
          end
        rescue NameError
          raise InvalidValidatorException.new(validator_name)
        end
      end
      errors
    end
  end
end

