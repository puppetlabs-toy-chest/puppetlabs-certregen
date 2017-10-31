Puppet::Parser::Functions::newfunction(:is_classified_with, :arity => 1,
                                       :type => :rvalue) do |arguments|
  compiler.node.classes.keys.include?(arguments[0])
end
