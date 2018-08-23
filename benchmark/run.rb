require "dummy/schema"
require "benchmark/ips"
require 'ruby-prof'
require 'memory_profiler'
require 'rblineprof'

module GraphQLBenchmark
  QUERY_STRING = GraphQL::Introspection::INTROSPECTION_QUERY
  DOCUMENT = GraphQL.parse(QUERY_STRING)
  SCHEMA = Dummy::Schema

  BENCHMARK_PATH = File.expand_path("../", __FILE__)
  CARD_SCHEMA = GraphQL::Schema.from_definition(File.read(File.join(BENCHMARK_PATH, "schema.graphql")))
  ABSTRACT_FRAGMENTS = GraphQL.parse(File.read(File.join(BENCHMARK_PATH, "abstract_fragments.graphql")))
  ABSTRACT_FRAGMENTS_2 = GraphQL.parse(File.read(File.join(BENCHMARK_PATH, "abstract_fragments_2.graphql")))


  BIG_SCHEMA = GraphQL::Schema.from_definition(File.join(BENCHMARK_PATH, "big_schema.graphql"))
  BIG_QUERY = GraphQL.parse(File.read(File.join(BENCHMARK_PATH, "big_query.graphql")))

  module_function
  def self.run(task)
    Benchmark.ips do |x|
      case task
      when "line profile"
        profile { BIG_SCHEMA.execute(document: BIG_QUERY) }
      when "query"
        x.report("query") { SCHEMA.execute(document: DOCUMENT) }
      when "validate"
        x.report("validate - introspection ") { CARD_SCHEMA.validate(DOCUMENT) }
        x.report("validate - abstract fragments") { CARD_SCHEMA.validate(ABSTRACT_FRAGMENTS) }
        x.report("validate - abstract fragments 2") { CARD_SCHEMA.validate(ABSTRACT_FRAGMENTS_2) }
        x.report("validate - big query") { BIG_SCHEMA.validate(BIG_QUERY) }
      else
        raise("Unexpected task #{task}")
      end
    end
  end

  def self.line_profile
    line_profile = lineprof(/./) do
      BIG_SCHEMA.execute(document: BIG_QUERY)
    end

    per_file = line_profile.map do |file, lines|
      total, child, excl, total_cpu, child_cpu, excl_cpu = lines[0]

      summary = "total"
      wall = summary == "exclusive" ? excl : total
      cpu  = summary == "exclusive" ? excl_cpu : total_cpu
      idle = summary == "exclusive" ? (excl-excl_cpu) : (total-total_cpu)

      [
        file, lines,
        wall, cpu, idle,
        wall
      ]
    end.sort_by{ |a, b, c, d, e, f| -f }

    output = ""
    output << "  CPU TIME +  IDLE TIME   FILE\n"
    min = 80
    mode = "cpu"

    per_file.each do |file_name, lines, file_wall, file_cpu, file_idle, file_sort|
      show_src = file_sort > min
      tmpl = show_src ? "<a href='#' class='js-lineprof-file'>%s</a>" : "%s"

      if mode == "cpu"
        output << sprintf("% 8.1fms + % 8.1fms   #{tmpl}\n", file_cpu/1000.0, file_idle/1000.0, file_name.sub("#{@root}/", ""))
      else
        output << sprintf("% 8.1fms   #{tmpl}\n", file_wall/1000.0, file_name.sub("#{@root}/", ""))
      end

      next unless show_src

      output << "<div class='d-none'>"
      File.readlines(file_name).each_with_index do |line, i|
        wall, cpu, calls = lines[i+1]

        if calls && calls > 0
          if mode == "cpu"
            idle = wall - cpu
            output << sprintf("% 8.1fms + % 8.1fms (% 5d) | %s", cpu/1000.0, idle/1000.0, calls, CGI.escapeHTML(line))
          else
            output << sprintf("% 8.1fms (% 5d) | %s", wall/1000.0, calls, CGI.escapeHTML(line))
          end
        end
      end
      output << "</div>"
    end

    File.open("profile.html", "w") { |file| file.write("<div id='line-profile'><pre>#{output}</pre></div>") }
  end

  def self.profile
    # Warm up any caches:
    SCHEMA.execute(document: DOCUMENT)
    # CARD_SCHEMA.validate(ABSTRACT_FRAGMENTS)

    result = RubyProf.profile do
      # CARD_SCHEMA.validate(ABSTRACT_FRAGMENTS)
      SCHEMA.execute(document: DOCUMENT)
    end

    printer = RubyProf::FlatPrinter.new(result)
    # printer = RubyProf::GraphHtmlPrinter.new(result)
    # printer = RubyProf::FlatPrinterWithLineNumbers.new(result)

    printer.print(STDOUT, {})
  end
end
