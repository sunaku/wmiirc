#--
# Copyright protects this work.
# See LICENSE file for details.
#++

require 'yaml'

module Wmii
  class Config < Hash
    BASE_DIR = File.dirname(__FILE__)

    def initialize name
      import name, self
    end

    private

    def import paths, merged = {}, imported = []
      Array(paths).each do |path|
        path = File.join(BASE_DIR, path) + '.yaml'

        partial = YAML.load_file(path)
        imports = Array(partial['import'])

        # prevent cycles
        imports -= imported
        imported.concat imports

        import imports, merged, imported
        merge partial, merged
      end

      merged
    end

    def merge src_hash, dst_hash
      src_hash.each_pair do |key, src_val|
        # skip nil values
        next if src_val.nil?

        if dst_val = dst_hash[key]

          # merge the values
          case dst_val
          when Hash
            merge src_val, dst_val

          when Array
            case src_val
            when Array
              dst_val.concat src_val
            else
              dst_val.push src_val
            end

          else
            raise NotImplementedError, 'merge val %s into %s for key %s' % [
              src_val.inspect, dst_val.inspect, key.inspect
            ]
          end

        else
          dst_hash[key] = src_val
        end
      end
    end

  end
end
