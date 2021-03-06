gem "rdoc"

require "pathname"
require "fileutils"
require "rdoc/rdoc"
require "rdoc/generator"
require "json"

class RDoc::Generator::RDocJSON
  include FileUtils

  RDoc::RDoc.add_generator(self)

  # Instanciates this generator. Automatically called
  # by RDoc.
  # ==Parameter
  # [options]
  #   RDoc passed the current RDoc::Options instance.
  def initialize(store, options)
    @store   = store
    @options = options
    @op_dir  = Pathname.pwd.expand_path + @options.op_dir
  end

  # Outputs a string on standard output, but only if RDoc
  # was invoked with the <tt>--debug</tt> switch.
  def debug(str)
    puts(str) if $DEBUG_RDOC
  end

  # Main hook method called by RDoc, triggers the generation process.
  def generate
    debug "Sorting classes, modules, and methods..."

    @toplevels = @store.all_files

    @classes_and_modules = @store.all_classes_and_modules.sort_by do |klass|
      klass.full_name
    end

    @methods = @classes_and_modules.map do |mod|
      mod.method_list
    end.flatten.sort

    # Create the output directory
    mkdir @op_dir unless @op_dir.exist?

    generate_json_file
  end

  # Darkfish returns +nil+, hence we do this as well.
  def file_dir
    nil
  end

  # Darkfish returns +nil+, hence we do this as well.
  def class_dir
    nil
  end

  def generate_json_file
    json = {}

    json["toplevels"] = @toplevels.map do |toplevel|
      {
        name: toplevel.name,
        description: toplevel.description
      }
    end

    json["classes_and_modules"] = @classes_and_modules.map do |classmod|
      {
        name: classmod.full_name,
        superclass: classmod.module? ? "" : classmod.superclass,
        method_list: classmod.each_method.to_a.map do |method|
          { name: method.pretty_name }
        end,
        description: classmod.description,
        includes: classmod.includes.map do |included|
          { name: included.full_name }
        end,
        constants: classmod.constants.map do |const|
          {
            name: const.name,
            value: const.value,
            description: const.description
          }
        end,
        attributes: classmod.attributes.map do |attribute|
          {
            name: attribute.name,
            description: attribute.description
          }
        end
      }
    end

    json["methods"] = @methods.map do |method|
      {
        type: method.type,
        visibility: method.visibility,
        arglists: method.arglists,
        description: method.description,
        markup_code: method.markup_code,
      }
    end

    File.write(@op_dir + "all.json", JSON.pretty_generate(json))
  end
end
