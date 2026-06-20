defmodule PaianjenWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """
  use PaianjenWeb, :html

  # Import CoreComponents so embedded templates can call components like flash_group
  import PaianjenWeb.CoreComponents

  embed_templates "layouts/*"
end
