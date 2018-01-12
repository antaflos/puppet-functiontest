require File.join(File.dirname(__FILE__), '../../..', 'puppet_x/functiontest/utils.rb')

module Puppet::Parser::Functions
  newfunction(:envtestfunction, :type => :rvalue) do |args|
    raise Puppet::ParseError, 'Must provide exactly one argument.' if args.length != 1

    PuppetX::Functiontest::Utils.format_content(args[0])
  end
end
