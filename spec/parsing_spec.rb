# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe "Parsing" do
  describe "#parse" do
    it "returns Psych::Nodes::Document" do
      ast = Psych::Comments.parse("- 1")
      expect(ast).to be_a(Psych::Nodes::Document)
    end

    it "accepts filename" do
      ast = Psych::Comments.parse("- 1", filename: "foo.yml")
      expect(ast).to be_a(Psych::Nodes::Document)
    end

    it "accepts IO" do
      ast = Psych::Comments.parse(StringIO.new "- 1")
      expect(ast).to be_a(Psych::Nodes::Document)
    end

    it "attaches comments to a scalar" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        bar
      YAML
      expect(ast.root.leading_comments).to eq(["# foo"])
      expect(ast.root.inline_comment).to eq(nil)
      expect(ast.root.trailing_comments).to eq([])
    end

    it "attaches inline comments to a scalar" do
      ast = Psych::Comments.parse(<<~YAML)
        bar # foo
      YAML
      expect(ast.root.leading_comments).to eq([])
      expect(ast.root.inline_comment).to eq("# foo")
      expect(ast.root.trailing_comments).to eq([])
    end

    it "attaches multiple comments to a scalar" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        # bar
        baz
      YAML
      expect(ast.root.leading_comments).to eq(["# foo", "# bar"])
    end

    it "attaches leading comments to a mapping key" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        bar: baz
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect(ast.root.children[0].leading_comments).to eq(["# foo"])
    end

    it "attaches inline comments to a mapping key" do
      ast = Psych::Comments.parse(<<~YAML)
        bar: # foo
          baz
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect(ast.root.children[0].inline_comment).to eq("# foo")
      expect(ast.root.children[1].inline_comment).to eq(nil)
    end

    it "attaches inline comments to a mapping value" do
      ast = Psych::Comments.parse(<<~YAML)
        bar: baz # foo
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect(ast.root.children[0].inline_comment).to eq(nil)
      expect(ast.root.children[1].inline_comment).to eq("# foo")
    end

    it "attaches leading comments to a mapping value" do
      ast = Psych::Comments.parse(<<~YAML)
        bar:
          # foo
          baz
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect(ast.root.children[1].leading_comments).to eq(["# foo"])
    end

    it "attaches comments to sequence elements" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        - foo1
        - # bar
          bar2
        # baz-a
        - # baz-b
          foo3: bar3 # baz-c
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Sequence)
      expect(ast.root.children[0].leading_comments).to eq(["# foo"])
      expect(ast.root.children[1].leading_comments).to eq(["# bar"])
      expect(ast.root.children[2].leading_comments).to eq(["# baz-a"])
      expect(ast.root.children[2].children[1].inline_comment).to eq("# baz-c")
    end

    it "attaches inline comments to sequence elements containing flow mappings/sequences" do
      ast = Psych::Comments.parse(<<~YAML)
        - [] # empty array
        - [1, 2] # array of integers
        - {} # empty map
        - { foo: bar } # map with one key-value pair
      YAML
      expected_comments = {
        ast.root.children[0] => "# empty array",
        ast.root.children[1] => "# array of integers",
        ast.root.children[2] => "# empty map",
        ast.root.children[3] => "# map with one key-value pair"
      }
      visit = lambda do |node|
        expect(node.inline_leading_comment).to eq(nil) if node.is_a?(Psych::Nodes::Sequence) || node.is_a?(Psych::Nodes::Mapping)
        expect(node.inline_comment).to eq(expected_comments[node])
        expect(node.leading_comments).to eq([])
        expect(node.trailing_comments).to eq([])
        node.children&.each { |child| visit.call(child) }
      end
      visit.call(ast.root)
    end

    it "attaches inline comments to empty flow mapping/sequence" do
      ast = Psych::Comments.parse(<<~YAML)
        foo: {} # foo
        bar: [] # bar
      YAML

      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect(ast.root.children[1].inline_comment).to eq("# foo")
      expect(ast.root.children[3].inline_comment).to eq("# bar")
    end

    it "attaches inline comments only to flow mapping/sequence" do
      ast = Psych::Comments.parse(<<~YAML)
        foo: { key: "name", values: 1 } # foo
        bar: [{ key: "name", values: 2}] # bar
        baz:
        - { key: "name", values: 3 } # baz
      YAML
      expected_comments = {
        ast.root.children[1] => "# foo",
        ast.root.children[3] => "# bar",
        ast.root.children[5].children[0] => "# baz"
      }
      visit = lambda do |node|
        expect(node.inline_comment).to eq(expected_comments[node])
        expect(node.leading_comments).to eq([])
        expect(node.trailing_comments).to eq([])
        node.children&.each { |child| visit.call(child) }
      end
      visit.call(ast.root)
    end

    it "attaches comments to flow mapping" do
      ast = Psych::Comments.parse(<<~YAML)
        # leading
        { # inline leading
          # foo
          foo: bar # bar
          # baz
        } # inline trailing
        # trailing
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Mapping)
      expect(ast.root.leading_comments).to eq(["# leading"])
      expect(ast.root.inline_leading_comment).to eq("# inline leading")
      expect(ast.root.inline_comment).to eq("# inline trailing")
      expect(ast.trailing_comments).to eq(["# trailing"])
      expect(ast.root.children[0].leading_comments).to eq(["# foo"])
      expect(ast.root.children[1].inline_comment).to eq("# bar")
      expect(ast.root.children[1].trailing_comments).to eq(["# baz"])
    end

    it "attaches comments to flow sequence" do
      ast = Psych::Comments.parse(<<~YAML)
        # leading
        [ # inline leading
          # foo
          foo # bar
          # baz
        ] # inline trailing
        # trailing
      YAML
      expect(ast.root).to be_a(Psych::Nodes::Sequence)
      expect(ast.root.leading_comments).to eq(["# leading"])
      expect(ast.root.inline_leading_comment).to eq("# inline leading")
      expect(ast.root.inline_comment).to eq("# inline trailing")
      expect(ast.trailing_comments).to eq(["# trailing"])
      expect(ast.root.children[0].leading_comments).to eq(["# foo"])
      expect(ast.root.children[0].inline_comment).to eq("# bar")
      expect(ast.root.children[0].trailing_comments).to eq(["# baz"])
    end

    it "attaches comments to document" do
      ast = Psych::Comments.parse(<<~YAML)
        # foo
        ---
        # bar
        1
      YAML
      expect(ast.leading_comments).to eq(["# foo"])
      expect(ast.root.leading_comments).to eq(["# bar"])
    end

    it "attaches trailing comments in the last node of document" do
      ast = Psych::Comments.parse(<<~YAML)
        1
        # foo
        ...
        # bar
      YAML
      expect(ast.root.trailing_comments).to eq(["# foo"])
      expect(ast.trailing_comments).to eq(["# bar"])
    end
  end
end
