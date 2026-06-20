defmodule PaianjenWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.
  """
  use Phoenix.Component
  use Gettext, backend: PaianjenWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders a flash message.
  """
  attr :flash, :map, required: true
  attr :kind, :atom, values: [:info, :error]
  slot :inner_block, required: true

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = render_slot(@inner_block)}
      id={"flash-#{@kind}"}
      class={"fixed top-4 right-4 z-50 rounded-lg px-4 py-3 shadow-lg text-sm font-medium #{if(@kind == :info, do: "bg-emerald-50 text-emerald-800 border border-emerald-200", else: "bg-red-50 text-red-800 border border-red-200")}"}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind})}
    >
      <button type="button" class="float-right ml-3 opacity-60 hover:opacity-100">✕</button>
      <%= msg %>
    </div>
    """
  end

  @doc """
  Renders flash messages.
  """
  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <.flash kind={:info} flash={@flash}><%= Phoenix.Flash.get(@flash, :info) %></.flash>
    <.flash kind={:error} flash={@flash}><%= Phoenix.Flash.get(@flash, :error) %></.flash>
    """
  end

  @doc """
  Renders a simple form.
  """
  attr :for, :any, required: true
  attr :as, :any, default: nil
  attr :rest, :global, include: ~w(autocomplete name rel action enctype method novalidate target)
  slot :inner_block, required: true

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="mt-10 space-y-8 bg-white">
        <%= render_slot(@inner_block, f) %>
        <div :if={assigns[:actions]} class="mt-2 flex items-center justify-between gap-6">
          <%= render_slot(@actions, f) %>
        </div>
      </div>
    </.form>
    """
  end

  @doc """
  Renders an input with label and error messages.
  """
  attr :type, :string, default: "text"
  attr :label, :string, default: nil
  attr :value, :any
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :checked, :boolean, default: nil
  attr :prompt, :string, default: nil
  attr :options, :list, default: []
  attr :multiple, :boolean, default: false
  attr :rest, :global, include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{errors: errors}} = assigns) do
    assigns
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    ~H"""
    <div phx-feedback-for={@field.name}>
      <label class="flex items-center gap-4 text-sm leading-6 text-zinc-600">
        <input type="hidden" name={@field.name} value="false" />
        <input type="checkbox" id={@field.id} name={@field.name} value="true" checked={@checked} class="rounded border-zinc-300 text-zinc-900 focus:ring-zinc-900" {@rest} />
        <%= @label %>
      </label>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@field.name}>
      <.label for={@field.id}><%= @label %></.label>
      <select id={@field.id} name={@field.name} class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-800 focus:ring-zinc-800 sm:text-sm" multiple={@multiple} {@rest}>
        <option :if={@prompt} value=""><%= @prompt %></option>
        <option :for={opt <- @options} value={opt[:value] || opt} selected={opt[:value] in (@value || [])}><%= opt[:label] || opt[:value] || opt %></option>
      </select>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def input(assigns) do
    base_class = "block w-full rounded-lg border-zinc-300 focus:border-zinc-400 focus:ring-zinc-400 sm:text-sm"
    error_class = if @errors != [], do: " border-rose-400 focus:border-rose-400 focus:ring-rose-400", else: ""
    ~H"""
    <div phx-feedback-for={@field.name}>
      <.label :if={@label} for={@field.id}><%= @label %></.label>
      <div class={["mt-2", @label == nil && "mt-0"]}>
        <input type={@type} name={@field.name} id={@field.id} value={@value} class={"#{base_class}#{error_class}"} {@rest} />
      </div>
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  @doc """
  Renders a label.
  """
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-800">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot :inner_block, required: true

  def error(assigns) do
    ~H"""
    <p class="mt-3 flex gap-3 text-sm leading-6 text-rose-600">
      <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-5 w-5 flex-none" />
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  @doc """
  Renders a button.
  """
  attr :type, :string, default: nil
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={"rounded-lg bg-zinc-900 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-zinc-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-zinc-900 disabled:opacity-50 disabled:cursor-not-allowed #{@class}"}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders an icon.
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Translates an error message.
  """
  def translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  @doc """
  Translates the errors from a changeset.
  """
  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end
end
