# frozen_string_literal: true

class Psych::Nodes::Node
  attr_accessor :inline_comment

  def leading_comments
    @leading_comments ||= []
  end

  def trailing_comments
    @trailing_comments ||= []
  end
end
