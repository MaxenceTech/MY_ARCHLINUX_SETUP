# The following lines were added by compinstall

zstyle ':completion:*' completer _expand _complete _ignored _approximate
zstyle ':completion:*' format 'Completing %d'                                             
zstyle ':completion:*' group-name ''                                                                                 
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|[p]=** r:|=**' 'l:|=* r:|=*'
zstyle ':completion:*' menu select=1
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle :compinstall filename '/home/maxence/.zshrc'

autoload -Uz compinit                    
compinit               
# End of lines added by compinstall
# Lines configured by zsh-newuser-install
HISTFILE=~/.zsh_history
HISTSIZE=1000                                   
SAVEHIST=2000                                                    
bindkey -e                                                                       
# End of lines configured by zsh-newuser-install                         
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme                          
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh   
source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
source /usr/share/zsh/plugins/plugins_sudo_zsh/zsh_sudo_plugin.zsh
source /usr/share/zsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

alias ls='ls --color=auto'
alias diff='diff --color=auto'
alias grep='grep --color=auto'                                  
alias ip='ip -color=auto'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh                                                                                                                           

export LESS='-R --use-color -Dd+r$Du+b'