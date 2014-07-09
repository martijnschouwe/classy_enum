module ClassyEnum
  extend ActiveSupport::Concern

  module ClassMethods

    # Class macro used to associate an enum with an attribute on an Mongoid model.
    # This method is automatically added to all Mongoid models when the classy_enum gem
    # is installed. Accepts an argument for the enum class to be associated with
    # the model. Mongoid validation is automatically added to ensure
    # that a value is one of its pre-defined enum members.
    #
    # ==== Example
    #  # Associate an enum Priority with Alarm model's priority attribute
    #  class Alarm
    #    include Mongoid::Document
    #    classy_enum_attr :priority
    #  end
    #
    #  # Associate an enum Priority with Alarm model's alarm_priority attribute
    #  classy_enum_attr :alarm_priority, :enum => 'Priority'
    #
    #  # Allow enum value to be nil
    #  classy_enum_attr :priority, :allow_nil => true
    #
    #  # Allow enum value to be blank
    #  classy_enum_attr :priority, :allow_blank => true
    #
    #  # Specifying a default enum value
    #  classy_enum_attr :priority, :default => 'low'
    def classy_enum_attr(attribute, options={})
      enum              = (options[:enum] || options[:class_name] || attribute).to_s.camelize.constantize
      allow_blank       = options[:allow_blank] || false
      allow_nil         = options[:allow_nil] || false
      serialize_as_json = options[:serialize_as_json] || false
      default           = ClassyEnum._normalize_default(options[:default], enum)

      # Add ActiveRecord validation to ensure it won't be saved unless it's an option
      validates_inclusion_of attribute,
                             :in          => enum,
                             :allow_blank => allow_blank,
                             :allow_nil   => allow_nil

      # Define getter method that returns a ClassyEnum instance
      define_method attribute do
        enum.build(read_attribute(attribute),
                   :owner             => self,
                   :serialize_as_json => serialize_as_json,
                   :allow_blank       => (allow_blank || allow_nil)
        )
      end

      # Define setter method that accepts string, symbol, instance or class for member
      define_method "#{attribute}=" do |value|
        value = ClassyEnum._normalize_value(value, default, (allow_nil || allow_blank))
        super(value)
      end

      # Initialize the object with the default value if it is present
      # because this will let you store the default value in the
      # database and make it searchable.
      if default.present?
        after_initialize do
          value = read_attribute(attribute)

          if (value.blank? && !(allow_blank || allow_nil)) || (value.nil? && !allow_nil)
            send("#{attribute}=", default)
          end
        end
      end

    end

  end
end
if defined?(Mongoid::Document)
  Mongoid::Document.send(:include,ClassyEnum)
end