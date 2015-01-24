require "ostruct"
require "optparse"
require "rake/file_list"
require "method_source"

module Rails
  class TestRunner
    class Options
      def self.parse(args)
        options = { backtrace: false, name: nil }

        opt_parser = ::OptionParser.new do |opts|
          opts.banner = "Usage: bin/rails test [options] [file or directory]"

          opts.separator ""
          opts.separator "Filter options:"
          opts.separator ""
          opts.separator <<-DESC
  You can run a single test by appending the line number to filename:

    bin/rails test test/models/user_test.rb:27

          DESC

          opts.on("-n", "--name [NAME]",
                  "Only run tests matching NAME") do |name|
            options[:name] = name
          end

          opts.separator ""
          opts.separator "Output options:"

          opts.on("-b", "--backtrace",
                  "show the complte backtrace") do
            options[:backtrace] = true
          end

          opts.separator ""
          opts.separator "Common options:"

          opts.on_tail("-h", "--help", "Show this message") do
            puts opts
            exit
          end
        end

        opt_parser.order!(args)

        if arg = args.shift
          if Dir.exists?(arg)
            options[:pattern] = "#{arg}/**/*_test.rb"
          else
            options[:filename], options[:line] = arg.split(':')
            options[:filename] = File.expand_path options[:filename]
            options[:line] &&= options[:line].to_i
          end
        end
        options
      end
    end

    def initialize(options = {})
      @options = options
    end

    def run
      $rails_test_runner = self
      run_tests
    end

    def find_method
      return @options[:name] if @options[:name]
      return unless @options[:line]
      method = test_methods.find do |location, test_method, start_line, end_line|
        location == @options[:filename] &&
          (start_line..end_line).include?(@options[:line].to_i)
      end
      method[1] if method
    end

    def show_backtrace?
      @options[:backtrace]
    end

    private
    def run_tests
      test_files.to_a.each do |file|
        require File.expand_path file
      end
    end

    def test_files
      return [@options[:filename]] if @options[:filename]
      if @options[:pattern]
        pattern = @options[:pattern]
      else
        pattern = "test/**/*_test.rb"
      end
      Rake::FileList[pattern]
    end

    def test_methods
      methods_map = []
      suites = Minitest::Runnable.runnables.shuffle
      suites.each do |suite_class|
        suite_class.runnable_methods.each do |test_method|
          method = suite_class.instance_method(test_method)
          location = method.source_location
          start_line = location.last
          end_line = method.source.split("\n").size + start_line - 1
          methods_map << [location.first, test_method, start_line, end_line]
        end
      end
      methods_map
    end
  end
end
