activate :syntax, line_numbers: true
activate :relative_assets

activate :blog do |blog|
  blog.default_extension = ".md"
  blog.tag_template = "tag.html"
  blog.calendar_template = "calendar.html"
  blog.paginate = true
  blog.per_page = 10
  blog.page_link = "page/{num}"
end

page "/feed.xml", layout: false
# set :markdown_engine, :redcarpet
# set :markdown, :fenced_code_blocks => true, :smartypants => true

set(
  :markdown,
  no_intra_emphasis:   true,
  tables:              true,
  gh_blockcode:        true,
  fenced_code_blocks:  true,
  autolink:            true,
  strikethrough:       true,
  lax_html_blocks:     true,
  space_after_headers: true,
  superscript:         true
)
set :markdown_engine, :redcarpet

set :css_dir, 'stylesheets'
set :js_dir, 'javascripts'
set :images_dir, 'images'
set :relative_links, true

configure :development do
  activate :livereload
end

configure :build do
  activate :minify_css
  activate :minify_javascript
  activate :asset_hash
end
