Puppet::Functions.create_function(:is_classified_with) do
  dispatch :is_classified_with do
    param 'String', :str
  end

  def is_classified_with(str)
    closure_scope.find_global_scope.compiler.node.classes.include?(str.to_s)
  end
end
