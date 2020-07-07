# -*- coding: utf-8 -*-
gem "rdoc"

require "pathname"
require "fileutils"
require "erb"
require "rdoc/rdoc"
require "rdoc/generator"

# This is the main generator class that is instanciated by RDoc when
# you order it to use the _emerald_ generator. It mainly works on
# ERB template files you can find in the <b>data/templates</b> directory,
# where each major component (read: classes and toplevel files) has a
# template file that is evaluated for it. The result is then injected
# into the layout template, <b>data/templates/layout.html.erb</b>, which
# is then evaluated as well.
#
# == About relative paths
# As the output generated by RDoc is supposed to be viewable by both
# visiting the doc/ directory with a browser and providing the doc/
# directory to an HTTP server, effectively making it the root directory,
# care has been taken to only use relative links in all the static HTML
# files. The key component for this to work is the #root_path method,
# which is called to set the relative path to the root directory (i.e.
# the output directory). When called without an argument, #root_path
# returns the value previously remembered (usually it contains a good
# number of <b>../</b> entries). This way, the root directory can be
# set whenever a new HTML file is going to be outputted and can then
# be referenced from the ERB template.
#
# == Darkfish compatibility
# RDoc’s HTML formatter  has a good number of helper methods that
# have a strong hint regarding "where what belongs". By using these
# helper methods itself when creating cross-references, the HTML
# formatter enforces both the directory structure of the output
# directory and the anchor names used for references inside a single
# HTML file. The only way to circumvent this is to write another
# formatter, which I don’t intend to as the standard HTML formatter
# does a good job for HTML stuff. A nice side effect is that Emerald’s
# documentation is compatible with Darkfish’s one when it comes to links
# to specific elements. For example, you can create a link to a method
# called Foo::Bar#baz somewhere on the web, and if the destinatinon
# website chooses to switch from Darkfish output to Emerald (which I
# hope!), the link will continue to work.
class RDoc::Generator::Emerald
  include FileUtils

  # Generic exception class for this generator.
  class EmeraldError < StandardError
  end

  # Tell RDoc about the new generator
  RDoc::RDoc.add_generator(self)

  # Description displayed in RDoc’s help.
  DESCRIPTION = "The only RDoc generator that makes your Ruby documentation a jewel, too"

  # Root directory of this project.
  ROOT_DIR = Pathname.new(__FILE__).dirname.parent.parent.parent

  # Where to find the non-code stuff.
  DATA_DIR = ROOT_DIR + "data"

  # Main template used as the general layout.
  LAYOUT_TEMPLATE = ERB.new(File.read(DATA_DIR + "templates" + "layout.html.erb"))

  # Subtemplates injected into the main template.
  TEMPLATES = {
    :toplevel    => ERB.new(File.read(DATA_DIR + "templates" + "toplevel.html.erb")),
    :classmodule => ERB.new(File.read(DATA_DIR + "templates" + "classmodule.html.erb"))
  }

  # The version number.
  VERSION = File.read(ROOT_DIR + "VERSION").chomp.freeze

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
    @classes_and_modules = @store.all_classes_and_modules.sort_by{|klass| klass.full_name}
    @methods = @classes_and_modules.map{|mod| mod.method_list}.flatten.sort

    # Create the output directory
    mkdir @op_dir unless @op_dir.exist?

    copy_base_files
    evaluate_toplevels
    evaluate_classes_and_modules
  end

  # Darkfish returns +nil+, hence we do this as well.
  def file_dir
    nil
  end

  # Darkfish returns +nil+, hence we do this as well.
  def class_dir
    nil
  end

  protected

  # Set/get the root directory.
  # == Parameter
  # [set_to (nil)]
  #   If passed, this method _sets_ the root directory rather
  #   than returning it.
  # == Return value
  # The current relative path to the root directory.
  # == Remarks
  # See the class’ introductory text for more information
  # on this.
  def root_path(set_to = nil)
    if set_to
      @root_path = Pathname.new(set_to)
    else
      @root_path ||= Pathname.new("./")
    end
  end

  # Set/get the page title.
  # == Parameter
  # [set_to (nil)]
  #   If passed, this method _sets_ the title rather
  #   than returning it.
  # == Return value
  # The current page title.
  # == Remarks
  # Works the same way as #root_path.
  def title(set_to = nil)
    if set_to
      @title = set_to
    else
      @title ||= ""
    end
  end

  # Takes a RDoc::TopLevel and transforms it into a complete pathname
  # relative to the output directory. Filename alterations
  # done by RDoc’s crossref-HTML formatter are honoured. Note you
  # have to prepend #root_path to get a complete href.
  def rdocize_toplevel(toplevel)
    Pathname.new("#{toplevel.relative_name.gsub(".", "_")}.html")
  end

  # Takes a RDoc::ClassModule and transforms it into a complete pathname
  # relative to the output directory. Filename alterations
  # done by RDoc’s crossref-HTML formatter are honoured. Note you
  # have to prepend #root_path to get a complete href.
  def rdocize_classmod(classmod)
    Pathname.new("#{classmod.full_name.split("::").join("/")}.html")
  end

  private

  def copy_base_files
    debug "Copying base base files..."
    mkdir @op_dir + "stylesheets" unless File.directory?(@op_dir + "stylesheets")

    cp   Dir[DATA_DIR + "stylesheets" + "*.css"], @op_dir + "stylesheets"
    cp_r DATA_DIR + "javascripts", @op_dir
    cp_r DATA_DIR + "images",      @op_dir
  end

  def evaluate_toplevels
    @toplevels.each do |toplevel|
      debug "Processing toplevel #{toplevel.name}..."

      root_path("../" * (toplevel.relative_name.split("/").count - 1)) # Last component is a filename
      title toplevel.relative_name

      # Create the path to the file if necessary
      path = @op_dir + rdocize_toplevel(toplevel)
      mkdir_p path.parent unless path.parent.exist?

      # Evaluate the actual file documentation
      File.open(path, "w") do |file|
        debug  "  => #{path}"
        file.write(render(:toplevel, binding))
      end
    end
  end

  def evaluate_classes_and_modules
    @classes_and_modules.each do |classmod|
      debug "Processing class/module #{classmod.full_name} (#{classmod.method_list.count} methods)..."

      path = @op_dir + rdocize_classmod(classmod)

      mkdir_p   path.parent unless path.parent.directory?
      title     classmod.full_name
      root_path "../" * (classmod.full_name.split("::").count - 1) # Last element is a file


      File.open(path, "w") do |file|
        debug "  => #{path}"
        file.write(render(:classmodule, binding))
      end
    end
  end

  # Renders the subtemplate +template_name+ in the +context+ of the
  # given binding, then injects it into the main template (which is
  # evaluated in the same +context+).
  #
  # Returns the resulting string.
  def render(template_name, context)
    render_into_layout{TEMPLATES[template_name].result(context)}
  end

  # Renders into the main layout. The return value of the block
  # passed to this method will be placed in the layout in place
  # of the +yield+ expression.
  def render_into_layout
    LAYOUT_TEMPLATE.result(binding)
  end

end
