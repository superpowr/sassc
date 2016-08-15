require_relative "test_helper"

module SassC
  class EngineTest < MiniTest::Test
    include TempFileTest

    def render(data)
      Engine.new(data).render
    end

    def test_line_comments
      template = <<-SCSS
.foo {
  baz: bang; }
      SCSS
      expected_output = <<-CSS
/* line 1, stdin */
.foo {
  baz: bang; }
      CSS
      output = Engine.new(template, line_comments: true).render
      assert_equal expected_output, output
    end

    def test_one_line_comments
      assert_equal <<CSS, render(<<SCSS)
.foo {
  baz: bang; }
CSS
.foo {// bar: baz;}
  baz: bang; //}
}
SCSS
      assert_equal <<CSS, render(<<SCSS)
.foo bar[val="//"] {
  baz: bang; }
CSS
.foo bar[val="//"] {
  baz: bang; //}
}
SCSS
  end

    def test_variables
      assert_equal <<CSS, render(<<SCSS)
blat {
  a: foo; }
CSS
$var: foo;

blat {a: $var}
SCSS

      assert_equal <<CSS, render(<<SCSS)
foo {
  a: 2;
  b: 6; }
CSS
foo {
  $var: 2;
  $another-var: 4;
  a: $var;
  b: $var + $another-var;}
SCSS
    end

    def test_precision
      template = <<-SCSS
$var: 1;
.foo {
  baz: $var / 3; }
SCSS
      expected_output = <<-CSS
.foo {
  baz: 0.33333333; }
CSS
      output = Engine.new(template, precision: 8).render
      assert_equal expected_output, output
    end

    def test_precision_not_specified
      template = <<-SCSS
$var: 1;
.foo {
  baz: $var / 3; }
SCSS
      expected_output = <<-CSS
.foo {
  baz: 0.33333; }
CSS
      output = Engine.new(template).render
      assert_equal expected_output, output
    end

    def test_dependency_filenames_are_reported
      base = temp_dir("").to_s

      temp_file("not_included.scss", "$size: 30px;")
      temp_file("import_parent.scss", "$size: 30px;")
      temp_file("import.scss", "@import 'import_parent'; $size: 30px;")
      temp_file("styles.scss", "@import 'import.scss'; .hi { width: $size; }")

      engine = Engine.new(File.read("styles.scss"))
      engine.render
      deps = engine.dependencies

      expected = ["/import.scss", "/import_parent.scss"]
      assert_equal expected, deps.map { |dep| dep.options[:filename].gsub(base, "") }.sort
      assert_equal expected, deps.map { |dep| dep.filename.gsub(base, "") }.sort
    end

    def test_no_dependencies
      engine = Engine.new("$size: 30px;")
      engine.render
      deps = engine.dependencies
      assert_equal [], deps
    end

    def test_not_rendered_error
      engine = Engine.new("$size: 30px;")
      assert_raises(NotRenderedError) { engine.dependencies }
    end

    def test_load_paths
      temp_dir("included_1")
      temp_dir("included_2")

      temp_file("included_1/import_parent.scss", "$s: 30px;")
      temp_file("included_2/import.scss", "@import 'import_parent'; $size: $s;")
      temp_file("styles.scss", "@import 'import.scss'; .hi { width: $size; }")

      assert_equal ".hi {\n  width: 30px; }\n", Engine.new(
        File.read("styles.scss"),
        load_paths: [ "included_1", "included_2" ]
      ).render
    end

    def test_load_paths_not_configured
      temp_file("included_1/import_parent.scss", "$s: 30px;")
      temp_file("included_2/import.scss", "@import 'import_parent'; $size: $s;")
      temp_file("styles.scss", "@import 'import.scss'; .hi { width: $size; }")

      assert_raises(SyntaxError) do
        Engine.new(File.read("styles.scss")).render
      end
    end

    def test_sass_variation
      sass = <<SASS
$size: 30px
.foo
  width: $size
SASS

    css = <<CSS
.foo {
  width: 30px; }
CSS

      assert_equal css, Engine.new(sass, syntax: :sass).render
      assert_equal css, Engine.new(sass, syntax: "sass").render
      assert_raises(SyntaxError) { Engine.new(sass).render }
    end

    def test_encoding_matches_input
      input = "$size: 30px;"
      input.force_encoding("UTF-8")
      output = Engine.new(input).render
      assert_equal input.encoding, output.encoding
    end

    def test_inline_source_maps
      template = <<-SCSS
.foo {
  baz: bang; }
      SCSS
      expected_output = <<-CSS
/* line 1, stdin */
.foo {
  baz: bang; }
      CSS

      output = Engine.new(template, {
        source_map_file: ".",
        source_map_embed: true,
        source_map_contents: true
      }).render

      assert_match /sourceMappingURL/, output
      assert_match /.foo/, output
    end

    def test_empty_template
      output = Engine.new('').render
      assert_equal '', output
    end

    def test_empty_template_returns_a_new_object
      input = ''
      output = Engine.new(input).render
      assert input.object_id != output.object_id, 'empty template must return a new object'
    end

    def test_empty_template_encoding_matches_input
      input = ''.force_encoding("ISO-8859-1")
      output = Engine.new(input).render
      assert_equal input.encoding, output.encoding
    end
  end
end
