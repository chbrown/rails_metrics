# Setup to ignore any query which is not a SELECT, INSERT, UPDATE
# or DELETE and queries made by the own store.
RailsMetrics.ignore :invalid_queries do |name, payload|
  name == "sequel.sql" &&
    payload[:sql] !~ /^(SELECT|INSERT|UPDATE|DELETE)/
end

module RailsMetrics
  module ORM
    # Include in your model to store metrics. For Sequel, you need the
    # following setup:
    #
    #   ...
    # 
    #
    # You can use any model name you wish. Next, you need to include
    # RailsMetrics::ORM::Sequel:
    #
    #   class Metric < Sequel::Model
    #     include RailsMetrics::ORM::Sequel
    # 
    #   end
    #

    ORM.primary_key_finder = :one
    ORM.delete_all         = :delete

    ORM.metric_model_properties = %w[
      name:string
      duration:integer
      request_id:integer
      parent_id:integer
      payload:text
      started_at:datetime
      created_at:datetime
    ]

    def self.add_metric_model_config(generator, file_name, class_name)
      generator.inject_into_class "app/models/#{file_name}.rb", class_name, <<-CONTENT
        include RailsMetrics::ORM::#{Rails::Generators.options[:rails][:orm].to_s.camelize}
      CONTENT
    end

    module Sequel
      extend  ActiveSupport::Concern
      include RailsMetrics::Store

      included do
        # Create a new connection pool just for the given resource
        plugin :serialization, :validation_helpers # ???
        # establish_connection(Rails.env)
      end
      
      module InstanceMethods
        # Set required validations
        def validate
          super
          validates_presence [:name, :started_at, :duration]
        end
      end

      module ClassMethods
        # Serialize payload data
        # serialize :payload

        # Select scopes
        def by_name name
          filter(:name => name)
        end
        def requests
          by_name "rack.request"
        end
        def by_request_id request_id
          filter(:request_id => request_id)
        end

        def earliest
          order(:started_at.asc, :id.asc)
        end
        def latest
          order(:started_at.desc, :id.desc)
        end
        def slowest
          order(:duration.desc)
        end
        def fastest
          order(:duration.asc)
        end

        def one pk_id
          self[pk_id]
        end
      end # ClassMethods

      protected
        def save_metric!
          save!
        end

    end # Sequel::
  end # ORM::
end # RailsMetrics::