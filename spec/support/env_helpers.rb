module EnvHelpers
  # Pretend these environment variables are set, for this test only.
  # Keeps tests independent of whatever is in your real .env file.
  def stub_env(vars)
    allow(ENV).to receive(:[]).and_call_original
    vars.each { |key, value| allow(ENV).to receive(:[]).with(key).and_return(value) }
  end
end