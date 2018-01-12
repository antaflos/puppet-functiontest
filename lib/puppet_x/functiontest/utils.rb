module PuppetX
  module Functiontest
    module Utils
      def self.format_content(content)

        def self.comment_content(content)
          return tail_content("# functiontest library function at #{File.dirname(__FILE__)}\n\n" + content)
        end

        def self.tail_content(content)
          return content + "\n\nSome more comments"
        end

        formatted_content = ''

        formatted_content = comment_content(content)
      end
    end
  end
end
