require 'wmiirc'
require 'yaml'

module Wmiirc
module Import
  extend self

  def import result, paths, origins={}, imported={}, importer=$0
    Array(paths).each do |path|
      next if imported[path]
      imported[path] = true

      begin
        data = YAML.load_file(path)
      rescue => error
        error.message << ' when importing %s into %s' %
          [path, importer].map(&:inspect)
        raise error
      end

      mark_origin data, path, origins
      expand result, data, path, origins, imported
      merge result, data, path, origins
    end

    result
  end

  def expand result, src_data, src_file, origins={}, imported={}
    to_import = expand_paths src_data['import']
    to_ignore = expand_paths src_data['ignore']
    import result, to_import - to_ignore, origins, imported, src_file
    result
  end

  def expand_paths virtual_paths
    Array(virtual_paths).flat_map do |virtual_path|
      Dir[File.join(DIR, virtual_path)]
    end
  end

  def merge dst_hash, src_hash, src_file, origins={}, backtrace=[]
    src_hash.each do |key, src_val|
      backtrace.push key

      catch :merged do
        if dst_hash.key? key
          dst_val = dst_hash[key]

          dst_file = origins[dst_val]
          section = backtrace.join(':')

          if src_val.nil?
            LOG.warn 'empty section %s in %s removes value %s from %s' %
            [section, src_file, dst_val, dst_file].map(&:inspect)

            dst_hash.delete key
            throw :merged

          elsif dst_val.is_a? Hash and src_val.is_a? Hash
            merge dst_val, src_val, src_file, origins, backtrace
            throw :merged

          elsif dst_val.is_a? Array
            dst_val.concat Array(src_val)
            throw :merged

          else
            LOG.warn 'value %s from %s overrides %s from %s in section %s' %
            [src_val, src_file, dst_val, dst_file, section].map(&:inspect)
            # fall through
          end
        end

        dst_hash[key] = src_val
      end

      backtrace.pop
    end

    dst_hash
  end

private

  def mark_origin data, origin, result
    result[data] =
      if result.key? data
        Array(result[data]).push(origin).uniq
      else
        origin
      end

    if data.respond_to? :each
      data.each do |*values|
        values.each do |value|
          mark_origin value, origin, result
        end
      end
    end
  end

end
end
