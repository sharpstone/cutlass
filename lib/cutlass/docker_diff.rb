# frozen_string_literal: true

module Cutlass
  class DockerDiff
    def initialize(before_ids: nil, get_image_ids_proc: -> { Docker::Image.all.map(&:id) })
      @before_ids = before_ids || get_image_ids_proc.call
      @get_image_ids_proc = get_image_ids_proc
    end

    def call
      DiffValue.new(
        before_ids: @before_ids,
        now_ids: @get_image_ids_proc.call
      )
    end

    class DiffValue
      attr_reader :diff_ids

      def initialize(before_ids:, now_ids:)
        @diff_ids = now_ids - before_ids
      end

      def changed?
        @diff_ids.any?
      end

      def same?
        !changed?
      end

      def leaked_images
        diff_ids.map do |id|
          Docker::Image.get(id)
        end
      end

      def to_s
        leaked_images.map do |image|
          "  tags: #{image.info["RepoTags"]}, id: #{image.id}"
        end.join($/)
      end
    end
  end
end
