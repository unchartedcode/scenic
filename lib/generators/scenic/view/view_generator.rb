require "rails/generators"
require "rails/generators/active_record"
require "generators/scenic/materializable"

module Scenic
  module Generators
    # @api private
    class ViewGenerator < Rails::Generators::NamedBase
      include Rails::Generators::Migration
      include Scenic::Generators::Materializable
      source_root File.expand_path("../templates", __FILE__)

      def create_views_directory
        unless views_directory_path.exist?
          empty_directory(views_directory_path)
        end
      end

      def create_view_definition
        if view_erb_template?
          template view_erb_path, definition.path
        elsif creating_new_view?
          create_file definition.path
        else
          copy_file previous_definition.full_path, definition.full_path
        end
      end

      def create_migration_file
        if creating_new_view? || destroying_initial_view?
          migration_template(
            "db/migrate/create_view.erb",
            "db/migrate/create_#{plural_file_name}.rb",
          )
        else
          migration_template(
            "db/migrate/update_view.erb",
            "db/migrate/update_#{plural_file_name}_to_version_#{version}.rb",
          )
        end
      end

      def self.next_migration_number(dir)
        ::ActiveRecord::Generators::Base.next_migration_number(dir)
      end

      no_tasks do
        def previous_version
          @previous_version ||=
            Dir.entries(views_directory_path)
              .map { |name| version_regex.match(name).try(:[], "version").to_i }
              .max
        end

        def version
          @version ||= destroying? ? previous_version : previous_version.next
        end

        def migration_class_name
          if creating_new_view?
            "Create#{class_name.gsub('.', '').pluralize}"
          else
            "Update#{class_name.pluralize}ToVersion#{version}"
          end
        end
      end

      private

      def views_directory_path
        @views_directory_path ||= Rails.root.join(*%w(db views))
      end

      def version_regex
        /\A#{plural_file_name}_v(?<version>\d+)\.sql\z/
      end

      def creating_new_view?
        previous_version == 0
      end

      def view_erb_template?
        File.exists?(view_erb_path)
      end

      def view_erb_path
        File.join(views_directory_path, "#{definition.name}.sql.erb")
      end

      def definition
        Scenic::Definition.new(plural_file_name, version)
      end

      def previous_definition
        Scenic::Definition.new(plural_file_name, previous_version)
      end

      def plural_file_name
        @plural_file_name ||= file_name.pluralize.gsub(".", "_")
      end

      def destroying?
        behavior == :revoke
      end

      def formatted_plural_name
        if plural_name.include?(".")
          "\"#{plural_name}\""
        else
          ":#{plural_name}"
        end
      end

      def destroying_initial_view?
        destroying? && version == 1
      end
    end
  end
end
