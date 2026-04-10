# frozen_string_literal: true

module StoredFiles
  module Adapters
    class Local
      def initialize(root:)
        @root = Pathname.new(root)
      end

      def store(key:, io:)
        path = path_for(key)
        FileUtils.mkdir_p(path.dirname)
        io.rewind if io.respond_to?(:rewind)

        path.binwrite(io.read)
      end

      def download(key:)
        path = path_for(key)
        return unless path.exist?

        path.binread
      end

      def delete(key:)
        path = path_for(key)
        File.delete(path) if path.exist?
      end

      def exist?(key:)
        path_for(key).exist?
      end

      private

      def path_for(key)
        candidate = @root.join(key.to_s)
        expanded_root = @root.expand_path.to_s
        expanded_candidate = candidate.expand_path.to_s
        raise ArgumentError, "invalid storage key" unless expanded_candidate.start_with?(expanded_root)

        candidate
      end
    end
  end
end
